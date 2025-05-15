#!/usr/bin/env nextflow

include { sqs_calc            } from "${baseDir}/modules/local/sqs_calc"
include { estimate_total_read } from "${baseDir}/modules/local/estimate_total_reads"
include { subsampling         } from "${baseDir}/modules/local/subsampling"
include { calc_dedup_rates    } from "${baseDir}/modules/local/dedup_rate_predict"

workflow preprocessing {
    take:
    ch_samplesheet
    subsampling_flag

    main:
    estimate_total_read(ch_samplesheet)
    ch_samplesheet
        .map { meta, fastq_1, fastq_2 ->
            tuple(meta.id, meta, fastq_1, fastq_2)
        }
        .join(estimate_total_read.out.ch_total_reads.map { meta, sub_ratio_str ->
            tuple(meta.id, sub_ratio_str)
        })
        .map { id, meta, fastq_1, fastq_2, sub_ratio_str ->
            def sub_ratio = 1.0
            try {
                sub_ratio = sub_ratio_str.trim().toFloat()
            } catch (Exception e) {
                println "Warning: Error parsing sub_ratio, using default value 1.0"
            }

            meta.sub_ratio = sub_ratio
            def original_coverage = params.target_x / sub_ratio
            def coverage_limit = params.coverage_limit ?: 40
            meta.estimated_coverage = original_coverage
            meta.subsampling = true
            if (subsampling_flag == false) {
                meta.subsampling = false
            } else {
                if ((sub_ratio > params.sub_limit) || (original_coverage > coverage_limit)) {
                    meta.subsampling = false
                }
            }
            return tuple(meta, fastq_1, fastq_2)
        }
        .set { ch_samplesheet_with_meta }
    calc_dedup_rates(ch_samplesheet_with_meta)
    sqs_calc(ch_samplesheet_with_meta)
    subsampling(ch_samplesheet_with_meta)

    emit:
    ch_sub_samplesheet = subsampling.out.ch_sub_samplesheet
    ch_processed_dir = subsampling.out.processed_dir
    ch_dedup_rates = calc_dedup_rates.out.dedup_out
    ch_sqs_file = sqs_calc.out.ch_sqs
}
