#!/usr/bin/env nextflow
import groovy.json.JsonSlurper

include { AESPA                                        } from "${baseDir}/workflow/aespa.nf"
include { FIND_RAW_DATA                                } from "${baseDir}/modules/local/find_raw_data"
include { INPUT_CHECK                                  } from "${baseDir}/subworkflow/local/input_check"
include { MAKE_DELIVERABLES                            } from "${baseDir}/subworkflow/local/make_deliverables"
include { MAKE_DELIVERABLES as MERGE_MAKE_DELIVERABLES } from "${baseDir}/subworkflow/local/make_deliverables"
// include { QC_CONFIRM                                   } from "${baseDir}/modules/local/QC_CONFIRM"
include { QC_CONFIRM as MERGE_QC_CONFIRM               } from "${baseDir}/modules/local/QC_CONFIRM"
include { RETRY_AESPA_WITHOUT_SUBSAMPLING              } from "${baseDir}/subworkflow/local/RETRY_AESPA_WITHOUT_SUBSAMPLING"
include { BLAST_UNMAPPED_READS                         } from "${baseDir}/modules/local/unmapped_reads_blastn"
include { LIMS_QC_API_CALL                             } from "${baseDir}/modules/API/wgs_qc"
include { LIMS_API_POST                                } from "${baseDir}/modules/API/LIMS_API_POST" 

workflow {
    main:
    def config = new JsonSlurper().parseText(file(params.ref_conf).text)
    INPUT_CHECK(
        file(params.order_info),
        file(params.sample_sheet),
        file(params.run_dir),
    )

    Channel.of(
        tuple(
            file(config.fasta),
            file(config.fai),
            file(config.dict)
        ))
        .set { ch_ref_path }

    Channel.of(
        tuple(
            file(config.bwamem2_index),
            file(config.fasta)
            )
        )
        .set { ch_bwamem2_index_path }
    INPUT_CHECK.out.ch_merged_samplesheet
        .map { meta, fastq_1, fastq_2 -> 
            // if (meta.app == 'Whole Genome Resequencing' &&
                // meta.desc == 'Fastq only' &&
                // (meta.species == 'Human' || meta.species_x == 'Homo sapiens(human)') &&
                // meta.service_group != 'CLIA') 
            if (meta.species == 'Human' || meta.species_x == 'Homo sapiens(human)')
            {
                return tuple(meta, fastq_1, fastq_2)
            }
            return []
        }
        .set { ch_samplesheet_mix }
    def mergeFlag = params.merge_flag.toString().toLowerCase().toBoolean()
    def merge = params.merge.toString().toLowerCase().toBoolean()

    if (!mergeFlag) {
        AESPA(ch_samplesheet_mix, ch_ref_path, ch_bwamem2_index_path, true)
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

        BLAST_UNMAPPED_READS(AESPA.out.ch_bam)
        RETRY_AESPA_WITHOUT_SUBSAMPLING(ch_qc_fail, ch_ref_path, ch_bwamem2_index_path)
        
        // if (merge) {
        //     RETRY_AESPA_WITHOUT_SUBSAMPLING.out.ch_qc_report
        //     .mix(branched_ch_qc.pass)
        //     .map { meta, file -> 
        //         return [meta.sample, [meta, file]]
        //     }
        //     .groupTuple()
        //     .flatMap { sample, group ->
        //         def first_meta = group[0][0]
        //         def files = group.collect { it[1] }
        //         return [[first_meta, files]]
        //     }
        //     .set { ch_grouped_responses }
        // QC_CONFIRM(ch_grouped_responses)
        // MAKE_DELIVERABLES(QC_CONFIRM.out.ch_confirmed)
        // }
    }
    else {
        ch_samplesheet_mix
            .map {meta, fastq_1, fastq_2 ->
                return tuple(meta.sample, [meta, fastq_1, fastq_2])
            }
            .groupTuple()
            .flatMap { sample, group ->
                def first_meta = group[0][0]
                def files = group.collect { it[1] }
                return [[first_meta, files]]
            }
            .set { ch_samplesheet_mix_single }
            
            MERGE_QC_CONFIRM(ch_samplesheet_mix_single)
            MERGE_MAKE_DELIVERABLES(MERGE_QC_CONFIRM.out.ch_confirmed)
        }
}

workflow.onComplete {
    println "Pipeline completed at: $workflow.complete"
    println "Execution status: ${ workflow.success ? 'OK' : 'failed' }"
}

// workflow.onError {
//     def subject = "Pipeline execution failed!"
//     def msg = """
//         Pipeline execution failed!
//         ---------------------------
//         Error message: ${workflow.errorMessage}
//         Completed at: ${workflow.complete}
//         Duration    : ${workflow.duration}
//         workDir     : ${workflow.workDir}
//         exit status : ${workflow.exitStatus}
//         """
    
//     ['mail', '-s', subject, params.email].execute() << msg
// }