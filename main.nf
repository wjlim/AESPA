#!/usr/bin/env nextflow

nextflow.enable.dsl = 2

include { AESPA                                     } from "${baseDir}/workflow/aespa.nf"
include { AESPA as AESPA_RETRY                      } from "${baseDir}/workflow/aespa.nf"
include { LIMS_API_POST as LIMS_API_POST_INIT       } from "${baseDir}/modules/API/LIMS_API_POST"
include { LIMS_API_POST as LIMS_API_POST_PASS       } from "${baseDir}/modules/API/LIMS_API_POST"
include { LIMS_API_POST as LIMS_API_POST_FAIL       } from "${baseDir}/modules/API/LIMS_API_POST"
include { LIMS_API_POST as LIMS_API_POST_RETRY_PASS } from "${baseDir}/modules/API/LIMS_API_POST"
include { LIMS_API_POST as LIMS_API_POST_RETRY_FAIL } from "${baseDir}/modules/API/LIMS_API_POST"
include { BLAST_UNMAPPED_READS                      } from "${baseDir}/modules/local/unmapped_reads_blastn"

workflow {
    main:
        if (params.genome && params.genomes.containsKey(params.genome)) {
        fasta = params.genomes[params.genome].fasta
        fai = params.genomes[params.genome].fai
        dict = params.genomes[params.genome].dict
        bwamem2_index = params.genomes[params.genome].bwamem2_index
        isaac_index = params.genomes[params.genome].isaac_index
    }
    def aligner = params.aligner
    def index = params.genomes[params.genome][aligner + "_index"]
    Channel.of(
        tuple(
            file(fasta),
            file(fai),
            file(dict),
        ))
        .set { ch_ref_path }

    Channel.fromPath(params.sample_sheet)
        .splitCsv(header:true)
        .flatMap {
            row ->
            def meta = [
                id:row.sample_id,
                prefix:row.prefix,
                fastq_1:row.fastq_1,
                fastq_2:row.fastq_2,
                recipe: row.recipe ?: "151-10-10-151",
                order: row.order ?: row.sample_id,
                key: row.UniqueKey ?: row.sample_id
            ]
            return [[meta, file(row.fastq_1), file(row.fastq_2)]]
        }
        .set { ch_samplesheet }

    AESPA(ch_samplesheet, ch_ref_path, index, aligner,true)

    AESPA.out.ch_qc_json.map { meta, json ->
        def content = file(json).text
        def json_content = new groovy.json.JsonSlurper().parseText(content)
        def qc_result = json_content[0]
        freemix = qc_result.xxFreemixAsn.toFloat()
        mapping_rate = qc_result.xxMapread2.toFloat()
        dedupped_rate = qc_result.xxDupread2.toFloat()
        def qc_flag = true
        if (freemix > params.freemix_limit || mapping_rate < params.mapping_rate_limit || dedupped_rate < params.deduplicate_rate_limit) {
            qc_flag = false
        }
        return tuple(meta, json, qc_flag)
    }.set { ch_qc_json_with_flag }
    if (params.retry == false ) {
        ch_qc_json_with_flag.map {meta, json, qc_flag ->
            [meta, json]
        }.set { ch_qc_json }
        LIMS_API_POST_INIT(ch_qc_json)
    } else {
        def ch_bams = AESPA.out.ch_bams
        ch_qc_json_with_flag.join(ch_bams, failOnMismatch:true)
        .branch {meta, json, qc_flag, bam, bai ->
            pass : qc_flag == true
            fail : qc_flag == false
        }
        .set { branched_qc_ch }

        branched_qc_ch.pass.map {meta, json, flag, bam, bai ->
            [meta, json, bam, bai]
        }.set { ch_passed_qc }
        LIMS_API_POST_PASS(ch_passed_qc)

        branched_qc_ch.fail
        .branch {meta, json, flag, bam, bai ->
            subsampled: meta.subsampling == true
            not_subsampled: !(meta.subsampling == true)
        }
        .set { branched_qc_faied_with_subsampling_flag }

        branched_qc_faied_with_subsampling_flag.not_subsampled.map {meta, json,flag, bam, bai ->
            [meta, json, flag, bam, bai]
        }.set { ch_failed_not_subsampled_qc }

        branched_qc_faied_with_subsampling_flag.subsampled.map {meta, json,flag, bam, bai ->
            [meta, meta.fastq_1, meta.fastq_2]
        }.set { ch_failed_subsampled_qc }
        AESPA_RETRY(ch_failed_subsampled_qc, ch_ref_path, index, aligner, false)
        AESPA_RETRY.out.ch_qc_json.map { meta, json ->
            def content = file(json).text
            def json_content = new groovy.json.JsonSlurper().parseText(content)
            def qc_result = json_content[0]
            freemix = qc_result.xxFreemixAsn.toFloat()
            mapping_rate = qc_result.xxMapread2.toFloat()
            dedupped_rate = qc_result.xxDupread2.toFloat()
            def qc_flag = true
            if (freemix > params.freemix_limit || mapping_rate < params.mapping_rate_limit || dedupped_rate < params.deduplicate_rate_limit) {
                qc_flag = false
            }
            return tuple(meta, json, qc_flag)
        }
        .set { ch_AESPA_RETRY_qc }
        def ch_retry_bams = AESPA_RETRY.out.ch_bams
        ch_AESPA_RETRY_qc.join(ch_retry_bams, failOnMismatch:true)
        .branch {meta, json, flag, bam, bai ->
            pass : flag == true
            fail : flag == false
        }
        .set { branched_AESPA_RETRY_qc }

        branched_AESPA_RETRY_qc.pass.map {meta, json, flag, bam, bai ->
            [meta, json]
        }.set { ch_AESPA_RETRY_qc_json }
        LIMS_API_POST_RETRY_PASS(ch_AESPA_RETRY_qc_json)

        branched_AESPA_RETRY_qc.fail
        .map {meta, json, flag, bam, bai -> [meta, json] }
        .set { ch_failed_AESPA_RETRY_qc_json }
        LIMS_API_POST_RETRY_FAIL(ch_failed_AESPA_RETRY_qc_json)

        if (params.blastn_db != null) {
            ch_failed_not_subsampled_qc.mix(ch_failed_AESPA_RETRY_qc_json)
            .map {meta, json, flag, bam, bai -> [meta, bam, bai] }
            .set { ch_failed_qc_bam }
            BLAST_UNMAPPED_READS(ch_failed_qc_bam)
        }
    }
}
