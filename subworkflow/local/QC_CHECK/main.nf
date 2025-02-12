include { LIMS_QC_API_CALL  as API_QC_CALL  } from "../../../modules/API/wgs_qc"
include { LIMS_API_POST     as API_POST     } from "../../../modules/API/LIMS_API_POST" 

workflow QC_CHECK {
    take:
    ch_qc_report

    main:
    API_QC_CALL(ch_qc_report)
    API_POST(LIMS_QC_API_CALL.out.ch_json_file)

    emit:
    ch_json_file = API_QC_CALL.out.ch_json_file
    ch_api_response_json = API_POST.out.ch_api_response_json
}