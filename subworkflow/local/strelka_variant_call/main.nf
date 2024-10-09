#!/usr/bin/env nextflow

include { variant_call   } from '../../../modules/local/strelka'
include { pass_filter    } from '../../../modules/local/vcf_pass_filter'

workflow variant_calling {
    take:
    ch_bam_combined

    main:
    variant_call(ch_bam_combined)
    pass_filter(variant_call.out.raw_vcf_file)

    emit:
    ch_filtered_vcf = pass_filter.out
    // ch_raw_vcf = variant_call.out.raw_vcf_file
}
