include { raw_data_search } from '../../../modules/local/file_search'
include { info_check      } from '../../../modules/local/info_check'

workflow INPUT_CHECK {
    take:
    order_info
    sample_sheet
    run_dir

    main:
        
    raw_data_search(sample_sheet, run_dir)
    info_check(
        raw_data_search.out.ch_samplesheet_path,
        order_info
    )

    info_check.out.ch_valid_samplesheet_path
        .splitCsv(header:true)
        .map{ row -> 
            def meta = [
                id:row.UniqueKey,
                fc_id:row.FCID,
                lane:row.Lane,
                sample:row.SampleID,
                index_seq:row['Index Seq'],
                desc:row.Description_y,
                control:row.Control,
                recipe:row.Recipe,
                orderator:row.Operator,
                order:row.Project_x,
                lib_type:row.LibraryType,
                species:row.Species_y,
                app:row.ApplicationType_x,
                grade:row.OrderGrade,
                run_scale:row.RunScale_x,
                institute:row.Institute,
                customer:row.Customer,
                run_type:row.RunningType,
                ref_ver:row.Ref_ver,
                lib_kit:row['Library Kit'],
                lib_protocol:row['Library Protocol'],
                service_group:row['Service Group'],
                pl_id:row['pl Id'],
                fastq_1:row.fastq_1,
                fastq_2:row.fastq_2
            ]
            [meta, row.fastq_1, row.fastq_2]
        }
        .set {ch_samplesheet}
    emit:
    ch_merged_samplesheet = ch_samplesheet
}
