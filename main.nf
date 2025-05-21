#!/usr/bin/env nextflow

nextflow.enable.dsl = 2

include { AESPA } from "${baseDir}/workflow/aespa.nf"
include { AESPA as AESPA_RETRY } from "${baseDir}/workflow/aespa.nf"
include { LIMS_API_POST } from "${baseDir}/modules/API/LIMS_API_POST"

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
        .map {
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
            return tuple( meta, file(row.fastq_1), file(row.fastq_2))
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
    }
    .branch {meta, json, qc_flag ->
        fail : qc_flag == false
        pass : qc_flag == true
    }
    .set { branched_qc_ch }

    branched_qc_ch.pass.map {meta, json, flag ->
        [meta, json]
    }.set { ch_passed_qc }

    def ch_bams = AESPA.out.ch_bams
    branched_qc_ch.fail.join(ch_bams, failOnMismatch:true)
    .branch {meta, json, flag, bam, bai ->
        subsampled: meta.subampling == true
        not_subsampled: !(meta.subampling == true)
    }
    .set { branched_qc_failed }

    branched_qc_failed.subsampled.map {meta, json,flag,bam,bai ->
        [meta, json, flag, bam, bai]
    }.set { ch_failed_subsampled_qc }

    branched_qc_failed.not_subsampled.map {meta, json,flag,bam,bai ->
        [meta, json, flag, bam, bai]
    }.set { ch_failed_not_subsampled_qc }

    ch_failed_subsampled_qc.map {meta, json,flag,bam,bai ->
        [meta, meta.fastq_1, meta.fastq_2]
    }.set { ch_failed_qc }
    AESPA_RETRY(ch_failed_qc, ch_ref_path, index, aligner, false)
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

    if (params.blast) {
        branched_AESPA_RETRY_qc.fail.map {meta, json, flag, bam, bai ->
            [meta, bam, bai]
        }.set { ch_failed_blast_qc }

        BLAST(ch_failed_blast_qc)
    }
}
