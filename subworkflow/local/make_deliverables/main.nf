include { REPORT_PREPARE       } from '../../../subworkflow/local/report_prepare'
include { passed_file_check } from '../../../modules/local/passed_file_check'
include { concat_raw_data } from '../../../modules/local/concat_raw_data'

workflow MAKE_DELIVERABLES {
    take:
    ch_confirm
    
    main:
    passed_file_check(ch_confirm)
    concat_raw_data(passed_file_check.out.ch_passed_files)
    REPORT_PREPARE(concat_raw_data.out.ch_merged_samplesheet)
    
    emit:
    ch_merged_samplesheet = concat_raw_data.out.ch_merged_samplesheet
}