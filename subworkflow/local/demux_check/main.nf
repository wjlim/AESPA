include { confirm_check } from '../../../modules/local/confirm_check'
workflow DEMUX_CHECK {
    take:
    ch_api_response
    
    main:
    confirm_check(ch_samplesheet)
}