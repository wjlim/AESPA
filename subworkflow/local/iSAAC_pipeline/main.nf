#!/usr/bin/env nextflow

include { iSAAC_alignment } from "${baseDir}/modules/local/iSAAC"
include { CREATE_FASTQINPUT_SAMPLESHEET } from "${baseDir}/modules/local/iSAAC_sample_sheet"

workflow iSAAC_alignment_workflow {
    take:
    ch_preprocess
    ref_ch

    main:
    CREATE_FASTQINPUT_SAMPLESHEET(ch_preprocess)
    ch_preprocess
        .join(CREATE_FASTQINPUT_SAMPLESHEET.out.ch_isaac_samplesheet)
        .combine(ref_ch)
        .set { ch_combined_input }
    iSAAC_alignment(ch_combined_input)
    emit:
    ch_bam = iSAAC_alignment.out.ch_bam
}
