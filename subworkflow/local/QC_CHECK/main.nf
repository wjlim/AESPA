include { LIMS_QC_API_CALL     } from "../../../modules/API/wgs_qc"
include { LIMS_API_POST        } from "../../../modules/API/LIMS_API_POST"
include { QC_CONFIRM           } from "../../../modules/local/QC_CONFIRM"

workflow QC_CHECK {
    take:
    ch_qc_report

    main:

    LIMS_QC_API_CALL(ch_qc_report)
    LIMS_API_POST(LIMS_QC_API_CALL.out.json_file)
    QC_CONFIRM(LIMS_API_POST.out.ch_api_response_json)

    emit:
    ch_api_response = LIMS_API_POST.out.ch_api_response_json
}
