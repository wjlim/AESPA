include { sample_md5check_sum } from '../../../modules/local/sample_md5check_sum'
include { sample_calc_fastqc } from '../../../modules/local/sample_calc_fastqc'
include { sample_sqs_calc } from '../../../modules/local/sample_sqs_calc'
include { sample_sqs_merge } from '../../../modules/local/sample_sqs_merge'

workflow REPORT_PREPARE {
    take:
    ch_merged_samplesheet
    
    main:
    sample_md5check_sum(ch_merged_samplesheet)
    sample_calc_fastqc(ch_merged_samplesheet)
    sample_sqs_calc(ch_merged_samplesheet)
    sample_sqs_merge(sample_sqs_calc.out.sqs_file_ch)
}