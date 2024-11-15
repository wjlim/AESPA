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
    subsampling            // Subsampling flag

    main:
    // Update samplesheet with subsampling flag
    ch_samplesheet
        .map { meta, fastq1, fastq2 ->
            meta.subsampling = subsampling
            [meta, fastq1, fastq2]
        }
        .set { ch_samplesheet_updated }
    
    // Run preprocessing workflow - includes QC and subsampling if needed
    preprocessing(ch_samplesheet_updated, subsampling)

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
        .join(preprocessing.out.ch_sqs_file)
        .join(preprocessing.out.ch_dedup_rates)
        .join(calc_bams.out.flagstat_out_file)
        .join(calc_bams.out.picard_insertsize_file)
        .join(calc_bams.out.gatk_doc_file)
        .join(calc_bams.out.freemix_out_file)
        .join(calc_bams.out.doc_distance_out_file)
        .join(calc_bams.out.ch_sex)
        .map { meta, out_vcf, sqs_file, kmer_out, flagstat_out, picard_insertsize, GATK_DOC, freemix_out, doc_distance_out_file, sex_file ->
            [meta, out_vcf, sqs_file, kmer_out, flagstat_out, picard_insertsize, GATK_DOC, freemix_out, doc_distance_out_file, sex_file]
        }
        .set { ch_summary_qc_input }
        
    // Generate final QC summary report
    summary_qc(ch_summary_qc_input)

    emit:
    ch_qc_report = summary_qc.out.qc_report    // Final QC report output
    ch_subratio = preprocessing.out.ch_subratio // Actual subsampling ratio used
}