#!/usr/bin/env nextflow

nextflow.enable.dsl = 2

include { validateParameters; paramsHelp; paramsSummaryLog; fromSamplesheet } from 'plugin/nf-validation'

// Print help message, supply typical command line usage
def helpMessage() {
    log.info paramsHelp("nextflow run main.nf --order_info order.txt --sample_sheet samples.csv")
}

// Validate parameters and print summary
def validateInputParameters() {
    if (params.help) {
        helpMessage()
        System.exit(0)
    }

    // Validate workflow parameters
    if (params.validate_params) {
        validateParameters()
    }

    // Print parameter summary log to screen
    log.info paramsSummaryLog(workflow)
}

// Has the run name been specified by the user?
// This has the bonus effect of catching both -name and --name
custom_runName = params.name
if (!(workflow.runName ==~ /[a-z]+_[a-z]+/)) {
    custom_runName = workflow.runName
}

include { AESPA                                        } from "${baseDir}/workflow/aespa.nf"
include { INPUT_CHECK                                  } from "${baseDir}/subworkflow/local/input_check"
include { QC_CONFIRM as MERGE_QC_CONFIRM               } from "${baseDir}/modules/local/QC_CONFIRM"
include { RETRY_AESPA_WITHOUT_SUBSAMPLING              } from "${baseDir}/subworkflow/local/RETRY_AESPA_WITHOUT_SUBSAMPLING"
include { BLAST_UNMAPPED_READS                         } from "${baseDir}/modules/local/unmapped_reads_blastn"
include { LIMS_QC_API_CALL                             } from "${baseDir}/modules/API/wgs_qc"
include { LIMS_API_POST                                } from "${baseDir}/modules/API/LIMS_API_POST" 

workflow {
    main:
    // Parameter validation
    validateInputParameters()
    
    // Check mandatory parameters
    if (!params.genome && !params.fasta) {
        exit 1, 'Either --genome or --fasta parameter must be provided'
    }

    // Set up genome variables
    if (params.genome && params.genomes.containsKey(params.genome)) {
        fasta = params.genomes[params.genome].fasta
        fai = params.genomes[params.genome].fai
        dict = params.genomes[params.genome].dict
        bwamem2_index = params.genomes[params.genome].bwamem2_index
    } else {
        fasta = params.fasta
        fai = params.fai
        dict = params.dict
        bwamem2_index = params.bwamem2_index
    }

    INPUT_CHECK(
        file(params.order_info),
        file(params.sample_sheet)
    )

    Channel.of(
        tuple(
            file(fasta),
            file(fai),
            file(dict)
        ))
        .set { ch_ref_path }

    Channel.of(
        tuple(
            file(bwamem2_index),
            file(fasta)
            )
        )
        .set { ch_bwamem2_index_path }
        
    AESPA(INPUT_CHECK.out.ch_merged_samplesheet, ch_ref_path, ch_bwamem2_index_path, true)
    
    if (params.lims_call) {
        LIMS_QC_API_CALL(AESPA.out.ch_qc_report)
        LIMS_API_POST(LIMS_QC_API_CALL.out.ch_json_file)
        LIMS_API_POST.out.ch_json_file
            .map {
                meta, json_file ->
                def content = file(json_file).text
                def json_content = new groovy.json.JsonSlurper().parseText(content)
                def qc_result = json_content[0]
                meta.freemix = qc_result.xxFreemixAsn.toFloat()
                meta.mapping_rate = qc_result.xxMapread2.toFloat()
                meta.dedupped_rate = qc_result.xxDupread2.toFloat()
                meta.failed_reason = []
                if (meta.freemix > params.freemix_limit || meta.freemix == 0) {
                    meta.failed_reason << "FM"
                }
                if (meta.mapping_rate < params.mapping_rate_limit) {
                    meta.failed_reason << "MR"
                }
                if (meta.dedupped_rate < params.deduplicate_rate_limit) {
                    meta.failed_reason << "DR"
                }
                meta.qc_failed = meta.failed_reason.size() > 0
                meta.fail_reason = meta.failed_reason.join(", ")

                return [meta, json_file]
            }
            .branch { meta, json_file ->
                pass: !(meta.qc_failed && meta.subsampling == true)
                fail: meta.qc_failed && meta.subsampling == true
            }
            .set { branched_ch_qc }
            
        branched_ch_qc.fail
            .map {meta, json_file ->
                return [meta, meta.fastq_1, meta.fastq_2]
            }
            .set { ch_qc_fail }

        RETRY_AESPA_WITHOUT_SUBSAMPLING(ch_qc_fail, ch_ref_path, ch_bwamem2_index_path)
    }

    BLAST_UNMAPPED_READS(AESPA.out.ch_bam)
}

workflow.onComplete {
    println "Pipeline completed at: $workflow.complete"
    println "Execution status: ${ workflow.success ? 'OK' : 'failed' }"
}
