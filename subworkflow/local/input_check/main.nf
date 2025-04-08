include { info_check      } from '../../../modules/local/info_check'

workflow INPUT_CHECK {
    take:
    order_info
    sample_sheet

    main:
        
    info_check(
        sample_sheet,
        order_info
    )

    info_check.out.ch_valid_samplesheet_path
        .splitCsv(header:true)
        .map{ row -> 
            def meta = [
                id:row.sample_id,
                prefix:row.prefix,
                lane:row.lane,
                fastq_1:row.fastq_1,
                fastq_2:row.fastq_2
            ]
            [meta, row.fastq_1, row.fastq_2]
        }
        .set {ch_samplesheet}

    emit:
    ch_merged_samplesheet = ch_samplesheet
}
