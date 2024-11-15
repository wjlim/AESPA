#!/usr/bin/env nextflow

include { calc_freemix_values     } from '../../../modules/local/verifybamid2'
include { calc_genome_coverage    } from '../../../modules/local/calc_genome_coverage'
include { calc_DOC                } from '../../../modules/local/calc_DOC'
include { calc_distance           } from '../../../modules/local/calc_distance'
include { calc_PE_insert_size     } from '../../../modules/local/calc_PE_insert_size'
include { calc_samtools_flagstat  } from '../../../modules/local/calc_samtools_flagstat'
// include { variant_calling         } from '../../../subworkflow/local/strelka_variant_call'
include { variant_call            } from '../../../modules/local/strelka'
include { pass_filter             } from '../../../modules/local/vcf_pass_filter'

workflow calc_bams {
    take:
    bam_ch
    ref_ch

    main:
    bam_ch
        .combine(ref_ch)
        .set {ch_bam_combined}
        
    calc_freemix_values(ch_bam_combined)
    calc_genome_coverage(bam_ch)
    calc_DOC(ch_bam_combined)
    calc_distance(bam_ch, calc_genome_coverage.out.ch_genomecov)
    calc_PE_insert_size(bam_ch)
    calc_samtools_flagstat(bam_ch)
    variant_call(ch_bam_combined)
    pass_filter(variant_call.out.raw_vcf_file)

    emit:
    flagstat_out_file = calc_samtools_flagstat.out
    picard_insertsize_file = calc_PE_insert_size.out
    gatk_doc_file = calc_DOC.out.sample_summary
    freemix_out_file = calc_freemix_values.out.vb2_out
    doc_distance_out_file = calc_distance.out
    ch_filtered_vcf = pass_filter.out.filtered_vcf
    ch_sex = calc_genome_coverage.out.ch_sex
}