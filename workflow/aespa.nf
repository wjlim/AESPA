include { preprocessing                                } from "${baseDir}/subworkflow/local/preprocessing"
include { iSAAC_alignment_workflow                     } from "${baseDir}/subworkflow/local/iSAAC_pipeline"
include { bwamem2_alignment_workflow                   } from "${baseDir}/subworkflow/local/bwa_pipeline"
include { calc_bams                                    } from "${baseDir}/subworkflow/local/bam_stat_calculation"
include { summary_qc                                   } from "${baseDir}/modules/local/summary_qc"

workflow AESPA {
    take:
    ch_samplesheet
    ch_ref_path
    index
    aligner
    subsampling

    main:
    ch_report = Channel.empty()

    preprocessing(ch_samplesheet, subsampling)
    ch_report = ch_report.mix(preprocessing.out.ch_sqs_file)
    ch_report = ch_report.join(preprocessing.out.ch_dedup_rates, failOnMismatch:true)
    ch_ref_path
        .map { fasta, fai, dict ->
            tuple(
                file(fasta),
                file(fai),
                file(dict),
                file(index)
            )
        }
        .set { ch_ref_path_with_index }
    if (aligner == "iSAAC") {
        iSAAC_alignment_workflow(
            preprocessing.out.ch_processed_dir,
            ch_ref_path_with_index
        )
        ch_bams = iSAAC_alignment_workflow.out.ch_bam
    } else if (aligner == "bwamem2") {
        bwamem2_alignment_workflow(
            preprocessing.out.ch_sub_samplesheet,
            file(index)
        )
        ch_bams = bwamem2_alignment_workflow.out.ch_bams
    } else {
        throw new Exception("Invalid aligner: ${aligner}")
    }

    calc_bams(ch_bams, ch_ref_path)
    ch_report = ch_report.join(calc_bams.out.flagstat_out_file, failOnMismatch:true)
    ch_report = ch_report.join(calc_bams.out.picard_insertsize_file, failOnMismatch:true)
    ch_report = ch_report.join(calc_bams.out.gatk_doc_file, failOnMismatch:true)
    ch_report = ch_report.join(calc_bams.out.freemix_out_file, failOnMismatch:true)
    ch_report = ch_report.join(calc_bams.out.doc_distance_out_file, failOnMismatch:true)
    ch_report = ch_report.join(calc_bams.out.ch_sex, failOnMismatch:true)
    ch_report = ch_report.join(calc_bams.out.ch_filtered_vcf, failOnMismatch:true)
    summary_qc(ch_report)

    emit:
    ch_qc_report = summary_qc.out.qc_report
    ch_qc_json = summary_qc.out.qc_json
    ch_bams = ch_bams
}
