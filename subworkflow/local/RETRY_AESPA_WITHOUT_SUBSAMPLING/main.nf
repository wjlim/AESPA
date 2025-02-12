include { AESPA as AESPA_RETRY                       } from "${baseDir}/workflow/aespa.nf"
include { LIMS_QC_API_CALL as LIMS_QC_API_CALL_RETRY } from "../../../modules/API/wgs_qc"
include { LIMS_API_POST as LIMS_API_POST_RETRY       } from "../../../modules/API/LIMS_API_POST"

workflow RETRY_AESPA_WITHOUT_SUBSAMPLING {
    take:
    ch_qc_fail
    ch_ref_path
    ch_bwamem2_index_path

    main:
    AESPA_RETRY(ch_qc_fail, ch_ref_path, ch_bwamem2_index_path, false)
    LIMS_QC_API_CALL_RETRY(AESPA_RETRY.out.ch_qc_report)
    LIMS_API_POST_RETRY(LIMS_QC_API_CALL_RETRY.out.ch_json_file)

    emit:
    ch_qc_report = AESPA_RETRY.out.ch_qc_report
}