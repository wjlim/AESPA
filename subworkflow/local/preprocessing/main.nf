#!/usr/bin/env nextflow

// include { md5check_sum        } from '../../../modules/local/md5check'
include { sqs_calc            } from '../../../modules/local/sqs_calc'
include { sqs_merge           } from '../../../modules/local/sqs_merge'
include { calc_fastqc         } from '../../../modules/local/calc_fastqc'
include { estimate_total_read } from '../../../modules/local/estimate_total_reads'
include { subsampling         } from '../../../modules/local/subsampling'
include { calc_dedup_rates    } from '../../../modules/local/dedup_rate_predict'

workflow preprocessing {
    take:
    ch_samplesheet
    subsampling_flag

    main:
    // md5check_sum(ch_samplesheet)
    sqs_calc(ch_samplesheet)
    sqs_merge(sqs_calc.out.sqs_file_ch)
    
    calc_dedup_rates(ch_samplesheet)
    estimate_total_read(ch_samplesheet)

    ch_samplesheet
        .join(estimate_total_read.out.ch_total_reads)
        .map { meta, fastq_1, fastq_2, sub_ratio_str ->
            def sub_ratio = 1.0
            try {
                sub_ratio = sub_ratio_str.trim().toFloat()
            } catch (Exception e) {
                println "Warning: Error parsing sub_ratio, using default value 1.0"
            }
            
            meta.sub_ratio = sub_ratio
            def original_coverage = params.target_x / sub_ratio
            def coverage_limit = params.coverage_limit ?: 40
            
            meta.subsampling = true
            if (subsampling_flag == false) {
                meta.subsampling = false
            } else {
                if ((sub_ratio > params.sub_limit) || (original_coverage > coverage_limit)) {
                    meta.subsampling = false
                }
            }
            println("sub_ratio: ${sub_ratio}, original_coverage: ${original_coverage}, coverage_limit: ${params.coverage_limit}; subsampling_flag: ${meta.subsampling}")
            return [meta, fastq_1, fastq_2]
        }
        .set { ch_samplesheet_with_meta }

    subsampling(ch_samplesheet_with_meta)
    
    emit:
    ch_sub_samplesheet = subsampling.out.ch_sub_samplesheet
    ch_processed_dir = subsampling.out.processed_dir
    ch_dedup_rates = calc_dedup_rates.out.dedup_out
    ch_sqs_file = sqs_merge.out.sqs_file
}
