#!/usr/bin/env nextflow

nextflow.enable.dsl=2
// Import required subworkflows and modules
include { preprocessing              } from "${baseDir}/subworkflow/local/preprocessing"
include { iSAAC_alignment_workflow   } from "${baseDir}/subworkflow/local/iSAAC_pipeline"
include { bwamem2_alignment_workflow } from "${baseDir}/subworkflow/local/bwa_pipeline"
include { calc_bams                  } from "${baseDir}/subworkflow/local/bam_stat_calculation"
include { summary_qc                 } from "${baseDir}/modules/local/summary_qc"

workflow AESPA {
    take:
    ch_samplesheet          // Input samplesheet channel
    ch_ref_path            // Reference genome path
    ch_bwamem2_index_path  // BWA-MEM2 index path
    subsampling_flag       // Subsampling flag

    main:
    preprocessing(ch_samplesheet, subsampling_flag)

    // Select and execute alignment workflow based on chosen aligner
    if (params.aligner == 'iSAAC') {
        // Run iSAAC alignment pipeline
        iSAAC_alignment_workflow(
            preprocessing.out.ch_processed_dir,
            ch_ref_path
        )
        ch_bams = iSAAC_alignment_workflow.out.ch_bam

    } else {
        // Run BWA-MEM2 alignment pipeline
        bwamem2_alignment_workflow(
            preprocessing.out.ch_sub_samplesheet,
            ch_bwamem2_index_path
        )
        ch_bams = bwamem2_alignment_workflow.out.ch_bams
    }
        
    // Calculate various BAM statistics and metrics
    calc_bams(ch_bams, ch_ref_path)

    // Combine all QC outputs for final summary
    // Join multiple QC outputs including:
    // - Filtered VCF
    // - Sequence Quality Score (SQS)
    // - Deduplication rates
    // - Flagstat metrics
    // - Insert size metrics
    // - Depth of Coverage
    // - Contamination estimates (freemix)
    // - Coverage distribution
    // - Sex determination
    calc_bams.out.ch_filtered_vcf
        .map { meta, out_vcf -> tuple(meta.id, meta, out_vcf) }
        .join(preprocessing.out.ch_sqs_file.map { meta, sqs_file -> tuple(meta.id, meta, sqs_file) })
        .join(preprocessing.out.ch_dedup_rates.map { meta, dedup_rates -> tuple(meta.id, meta, dedup_rates) })
        .join(calc_bams.out.flagstat_out_file.map { meta, flagstat_out -> tuple(meta.id, meta, flagstat_out) })
        .join(calc_bams.out.picard_insertsize_file.map { meta, picard_insertsize -> tuple(meta.id, meta, picard_insertsize) })
        .join(calc_bams.out.gatk_doc_file.map { meta, GATK_DOC -> tuple(meta.id, meta, GATK_DOC) })
        .join(calc_bams.out.freemix_out_file.map { meta, freemix_out -> tuple(meta.id, meta, freemix_out) })
        .join(calc_bams.out.doc_distance_out_file.map { meta, doc_distance_out_file -> tuple(meta.id, meta, doc_distance_out_file) })
        .join(calc_bams.out.ch_sex.map { meta, sex_file -> tuple(meta.id, meta, sex_file) })
        .map { id, meta, out_vcf, sqs_file, dedup_rates, flagstat_out, picard_insertsize, GATK_DOC, freemix_out, doc_distance_out_file, sex_file ->
            [meta, out_vcf, sqs_file, dedup_rates, flagstat_out, picard_insertsize, GATK_DOC, freemix_out, doc_distance_out_file, sex_file]
        }
        .set { ch_summary_qc_input }
        
    // Generate final QC summary report
    summary_qc(ch_summary_qc_input)

    emit:
    ch_bam = ch_bams
    ch_qc_report = summary_qc.out.qc_report    // Final QC report output
}