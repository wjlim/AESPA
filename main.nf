#!/usr/bin/env nextflow

nextflow.enable.dsl=2

import groovy.json.JsonSlurper

include { preprocessing } from './workflow/preprocessing.nf'
include { iSAAC_alignment_workflow } from './workflow/iSAAC_pipeline.nf'
include { calc_bams } from './workflow/bam_stat_calculation.nf'
include { make_qc_summary } from './workflow/summary_qc_stat.nf'
include { variant_calling } from './workflow/strelka_variant_call.nf'

params.result_dir = params.result_dir ?: ''
params.sample_sheet = params.sample_sheet ?: ''
params.forward_read = params.forward_read ?: ''
params.reverse_read = params.reverse_read ?: ''

def printHelpMessage() {
    println """
    Usage: nextflow run <script> --sample_sheet <path> --forward_read <path> --reverse_read <path> --result_dir <path>
    
    Parameters:
    --sample_sheet    Path to the sample sheet file (CSV format).
    --forward_read    Path to the forward read file.
    --reverse_read    Path to the reverse read file.
    --result_dir      Directory where results will be stored.
    
    Example:
    nextflow run my_pipeline.nf --sample_sheet /path/to/SampleSheet.csv --forward_read /path/to/forward.fastq --reverse_read /path/to/reverse.fastq --result_dir /path/to/results
    """
    System.exit(0)
}

if (!params.sample_sheet || !params.forward_read || !params.reverse_read || !params.result_dir) {
    printHelpMessage()
}

workflow {
    def config = new JsonSlurper().parseText(file(params.ref_conf).text)
    def sample_sheet = file(params.sample_sheet)
    def forward_read = file(params.forward_read)
    def reverse_read = file(params.reverse_read)
    def result_dir = file(params.result_dir)

    channel.fromPath(sample_sheet)
        .splitCsv(header:true)
        .first()
        .map { it -> 
            meta = [
                id:it.SampleID, 
                lib_group:it.Description, 
                oder_num:it.Project,
                result_dir: result_dir,
                sample_sheet_path:sample_sheet
                ]
            [meta, forward_read, reverse_read]
        }
        .set{reads_ch}

    ref_ch = channel.of(tuple(
            file(config.fasta), 
            file(config.fai), 
            file(config.dict)
        )
    )

    // Run preprocessing
    (processed_ch, kmer_out, sqs) = preprocessing(reads_ch)

    // Run iSAAC alignment workflow
    bam_ch = iSAAC_alignment_workflow(
        processed_ch,
        ref_ch
    )
    calc_bams(
        bam_ch,
        ref_ch
    )
    // Run variant calling
    (filtered_vcf_ch, raw_vcf) = variant_calling(
        bam_ch,
        ref_ch
    )
    
    make_qc_summary(
        filtered_vcf_ch,
        sqs,
        kmer_out,
        calc_bams.out.flagstat_out_file,
        calc_bams.out.picard_insertsize_file,
        calc_bams.out.gatk_doc_file,
        calc_bams.out.freemix_out_file,
        calc_bams.out.doc_distance_out_file
    )
}
