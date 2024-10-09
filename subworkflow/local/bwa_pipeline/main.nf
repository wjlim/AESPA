
include { BWAMEM2_MEM   } from '../../../modules/nf-core/bwamem2_mem'
include { BAM_SORT      } from '../../../modules/local/samtools_sort'

workflow bwamem2_alignment_workflow {
    take:
    ch_samplesheet
    ch_bwamem2_index_path

    main:
    ch_samplesheet
        .combine(ch_bwamem2_index_path)
        .set{ ch_bwamem_input }
    BWAMEM2_MEM(ch_bwamem_input)
    BAM_SORT(BWAMEM2_MEM.out.ch_bam)
    
    emit:
    ch_bams = BAM_SORT.out.ch_bams
}