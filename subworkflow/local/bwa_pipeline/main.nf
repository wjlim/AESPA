
include { BWAMEM2_MEM   } from '../../../modules/nf-core/bwamem2_mem'
include { MARK_DUP      } from '../../../modules/local/picard/markduplicates'

workflow bwamem2_alignment_workflow {
    take:
    ch_samplesheet
    bwamem2_index_path

    main:
    ch_samplesheet
        .map { meta, forward, reverse ->
            tuple(
                meta,
                forward,
                reverse,
                bwamem2_index_path
            )
        }
        .set { ch_bwamem_input }
    BWAMEM2_MEM(ch_bwamem_input)
    MARK_DUP(BWAMEM2_MEM.out.ch_bam)

    emit:
    ch_bams = MARK_DUP.out.ch_dedup_bams
    ch_bam_metrics = MARK_DUP.out.ch_metrics
}
