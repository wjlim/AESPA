#!/usr/bin/env nextflow

nextflow.enable.dsl=2

import groovy.json.JsonSlurper

include { preprocessing } from './workflow/preprocessing.nf'
include { iSAAC_alignment_workflow } from './workflow/iSAAC_pipeline.nf'
include { calc_bams } from './workflow/bam_stat_calculation.nf'
include { make_qc_summary } from './workflow/summary_qc_stat.nf'
include { variant_calling } from './workflow/strelka_variant_call.nf'

workflow {
    def config = new JsonSlurper().parseText(file(params.ref_conf).text)
    def input_info = new JsonSlurper().parseText(file(params.json_file).text)
    def sample_sheet = file(input_info.sample_sheet)
    def order_info = file(input_info.order_info)
    sample_sheet_ch = channel.fromPath(sample_sheet)
        .splitCsv(header:true)
        .multiMap {it ->
            // sample_id: it.SampleID
            lib_group: it.Description
            order_num: it.Project
        }
    input_ch = channel.of(tuple(
            input_info.sample_id, 
            file(input_info.raw_forward_input), 
            file(input_info.raw_reverse_input), 
            file(input_info.result_dir)
        )
    )

    ref_ch = channel.of(tuple(
            file(config.fasta), 
            file(config.fai), 
            file(config.dict)
        )
    )

    preprocessing(
        input_ch
    )
    
    iSAAC_alignment_workflow(
        input_ch,
        ref_ch,
        sample_sheet,
        preprocessing.out.processed_dir
    )

    iSAAC_alignment_workflow.out.sorted_bam
        .join(iSAAC_alignment_workflow.out.sorted_bai)
        .map{
            bam, bai ->
            tuple(
                input_info.sample_id, 
                bam, 
                bai, 
                input_info.result_dir
            )
        }
        .set{bam_ch}

    calc_bams(
        bam_ch,
        ref_ch
    )

    variant_calling(
        bam_ch,
        ref_ch
    )

    make_qc_summary(
        input_info.sample_id,
        sample_sheet_ch.order_num,
        sample_sheet_ch.lib_group,
        preprocessing.out.sqs_file,
        preprocessing.out.kmer_stats,
        variant_calling.out.strelka_vcf,
        calc_bams.out.flagstat_out_file,
        calc_bams.out.picard_insertsize_file,
        calc_bams.out.gatk_doc_file,
        calc_bams.out.freemix_out_file,
        calc_bams.out.doc_distance_out_file
    )
}
