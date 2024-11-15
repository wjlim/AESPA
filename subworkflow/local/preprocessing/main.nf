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
        .set { ch_combined_for_subsampling }
        
    subsampling(ch_combined_for_subsampling)
    if (subsampling_flag == true) {
        subsampling.out.ch_sub_samplesheet
            .join(subsampling.out.ch_subsampling_flag)
            .map{meta, fastq_1, fastq_2, flag -> 
                def flag_result = file(flag).text.trim()
                if (flag_result == 'true') {
                    meta.subsampling = true
                }
                else {
                    meta.subsampling = false
                }
                return [meta, fastq_1, fastq_2]
            }
            .set {ch_updated_sub_samplesheet}
            
        subsampling.out.processed_dir
            .join(subsampling.out.ch_subsampling_flag)
            .map{meta, dir, flag -> 
                def flag_result = file(flag).text.trim()
                if (flag_result == 'true') {
                    meta.subsampling = true
                }
                else {
                    meta.subsampling = false
                }
                return [meta, dir]
            }
            .set {ch_updated_prcessed_dir}
    }
    else {
        subsampling.out.ch_sub_samplesheet
            .map{meta, fastq_1, fastq_2 -> 
                meta.subsampling = false
                return [meta, fastq_1, fastq_2]
            }
            .set {ch_updated_sub_samplesheet}

        subsampling.out.processed_dir
            .join(subsampling.out.ch_subsampling_flag)
            .map{meta, dir, flag -> 
                meta.subsampling = false
                return [meta, dir]
            }
            .set {ch_updated_prcessed_dir}
    }
    
    emit:
    ch_sub_samplesheet = ch_updated_sub_samplesheet
    ch_processed_dir = ch_updated_prcessed_dir
    ch_dedup_rates = calc_dedup_rates.out.dedup_out
    ch_sqs_file = sqs_merge.out.sqs_file
    ch_subratio = subsampling.out.ch_ratio_file
}
