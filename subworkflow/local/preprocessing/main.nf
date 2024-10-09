#!/usr/bin/env nextflow

include { md5check_sum        } from '../../../modules/local/md5check'
include { sqs_calc            } from '../../../modules/local/sqs_calc'
include { sqs_merge           } from '../../../modules/local/sqs_merge'
include { calc_fastqc         } from '../../../modules/local/calc_fastqc'
include { estimate_total_read } from '../../../modules/local/estimate_total_reads'
include { subsampling         } from '../../../modules/local/subsampling'
include { calc_dedup_rates    } from '../../../modules/local/dedup_rate_predict'

workflow preprocessing {
    take:
    ch_samplesheet

    main:
    md5check_sum(ch_samplesheet)
    sqs_calc(ch_samplesheet)
    sqs_merge(sqs_calc.out.sqs_file_ch)
    estimate_total_read(ch_samplesheet)
    calc_dedup_rates(ch_samplesheet)
    subsampling(ch_samplesheet, estimate_total_read.out)

    emit:
    ch_sub_samplesheet = subsampling.out.ch_sub_samplesheet
    ch_processed_dir = subsampling.out.processed_dir
    ch_dedup_rates = calc_dedup_rates.out.dedup_out
    ch_sqs_file = sqs_merge.out.sqs_file
}
