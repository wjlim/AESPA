include { LIMS_QC_API_CALL                           } from "../../../modules/API/wgs_qc"
include { LIMS_API_POST                              } from "../../../modules/API/LIMS_API_POST" 
include { QC_CONFIRM                                 } from "../../../modules/local/QC_CONFIRM"
include { AESPA as AESPA_RETRY                       } from "${baseDir}/workflow/aespa.nf"
include { LIMS_QC_API_CALL as LIMS_QC_API_CALL_RETRY } from "../../../modules/API/wgs_qc"
include { LIMS_API_POST as LIMS_API_POST_RETRY       } from "../../../modules/API/LIMS_API_POST"

workflow QC_CHECK {
    take:
    ch_qc_report
    ch_ref_path
    ch_bwamem2_index_path

    main:
    ch_qc_check = Channel.empty()
    ch_qc_pass = Channel.empty()
    ch_qc_fail = Channel.empty()
    ch_all_responses = Channel.empty()

    if (params.lims_qc) {
        LIMS_QC_API_CALL(ch_qc_report, true)
        ch_qc_check = LIMS_QC_API_CALL.out.ch_json_file.map {
            meta, json_file ->
            def content = file(json_file).text
            def json_content = new groovy.json.JsonSlurper().parseText(content)
            def qc_result = json_content[0]

            def qc_failed = false
            def fail_reason = []
            if (qc_result.xxFreemixAsn.toFloat() > params.freemix_limit || qc_result.xxFreemixAsn.toFloat() == 0) {
                qc_failed = true
                fail_reason << "Freemix=${qc_result.xxFreemixAsn}"
            }
            if (qc_result.xxMapread2.toFloat() < params.mapping_rate_limit) {
                qc_failed = true
                fail_reason << "Mapping rate=${qc_result.xxMapread2}"
            }
            if (qc_result.xxDupread2.toFloat() < params.deduplicate_rate_limit) {
                qc_failed = true
                fail_reason << "Deduplicate rate=${qc_result.xxDupread2}"
            }
            if (meta.subsampling == false) {
                qc_failed = false
            }
            meta.qc_failed = qc_failed
            meta.fail_reason = fail_reason.join(", ")

            return [meta, json_file]
        }
        
        ch_qc_pass = ch_qc_check.filter { meta, json_file -> !meta.qc_failed }
        ch_qc_fail = ch_qc_check
                        .filter { meta, json_file -> meta.qc_failed }
                        .map {meta, json_file ->
                            return [meta, meta.fastq_1, meta.fastq_2]
                        }

        LIMS_API_POST(ch_qc_pass)
        ch_all_responses = LIMS_API_POST.out.ch_api_response_json

        // Retry AESPA for failed QC samples without subsampling_flag
        AESPA_RETRY(ch_qc_fail, ch_ref_path, ch_bwamem2_index_path, false)
        LIMS_QC_API_CALL_RETRY(AESPA_RETRY.out.ch_qc_report, false)
        LIMS_API_POST_RETRY(LIMS_QC_API_CALL_RETRY.out.ch_json_file)
        ch_all_responses = ch_all_responses.mix(LIMS_API_POST_RETRY.out.ch_api_response_json)

    } else {
        // When LIMS QC is disabled, use QC report directly
        ch_all_responses = ch_qc_report.map { meta, report ->
            return [meta, report]
        }
    }

    ch_grouped_responses = ch_all_responses
        .map { meta, file -> 
            return [meta.sample, [meta, file]]
        }
        .groupTuple()
        .map { sample, group ->
            def first_meta = group[0][0]
            def files = group.collect { it[1] }
            return [first_meta, files]
        }

    QC_CONFIRM(ch_grouped_responses)

    emit:
    ch_confirmed = QC_CONFIRM.out.ch_confirmed
}