#!/usr/bin/env nextflow

nextflow.enable.dsl=2
include { preprocessing              } from "${baseDir}/subworkflow/local/preprocessing"
include { iSAAC_alignment_workflow   } from "${baseDir}/subworkflow/local/iSAAC_pipeline"
include { bwamem2_alignment_workflow } from "${baseDir}/subworkflow/local/bwa_pipeline"
include { calc_bams                  } from "${baseDir}/subworkflow/local/bam_stat_calculation"
include { summary_qc                 } from "${baseDir}/modules/local/summary_qc"

workflow AESPA {
    take:
    ch_samplesheet
    ch_ref_path
    ch_bwamem2_index_path

    main:

    preprocessing(ch_samplesheet)
    // preprocessing.out.ch_sub_samplesheet.view()
    if (params.aligner == 'iSAAC') {
        iSAAC_alignment_workflow(
            preprocessing.out.ch_processed_dir,
            ch_ref_path
        )
        ch_bams = iSAAC_alignment_workflow.out.ch_bam
    } else {
        bwamem2_alignment_workflow(
            preprocessing.out.ch_sub_samplesheet,
            ch_bwamem2_index_path
        )
        ch_bams = bwamem2_alignment_workflow.out.ch_bams
    }
    calc_bams(
        ch_bams,
        ch_ref_path
    )
    calc_bams.out.ch_filtered_vcf
        .join(preprocessing.out.ch_sqs_file)
        .join(preprocessing.out.ch_dedup_rates)
        .join(calc_bams.out.flagstat_out_file)
        .join(calc_bams.out.picard_insertsize_file)
        .join(calc_bams.out.gatk_doc_file)
        .join(calc_bams.out.freemix_out_file)
        .join(calc_bams.out.doc_distance_out_file)
        .map { meta, out_vcf, sqs_file, kmer_out, flagstat_out, picard_insertsize, GATK_DOC, freemix_out, doc_distance_out_file ->
            tuple(meta, out_vcf, sqs_file, kmer_out, flagstat_out, picard_insertsize, GATK_DOC, freemix_out, doc_distance_out_file)
        }
        .set {ch_summary_qc_input}
        
    summary_qc(ch_summary_qc_input)

    emit:
    ch_qc_report = summary_qc.out.qc_report
}
