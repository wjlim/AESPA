process concat_raw_data {
    label 'process_single'
    tag "concat passed raw data for ${meta.sample}"

    input:
    tuple val(meta), path(passed_forward_list), path(passed_reverse_list)

    output:
    tuple val(meta), path("*_R1.fastq.gz"), path("*_R2.fastq.gz"), emit:ch_merged_samplesheet
    
    script:
    """
    cat \$(cat ${passed_forward_list}) > ${meta.sample}_R1.fastq.gz &
    cat \$(cat ${passed_reverse_list}) > ${meta.sample}_R2.fastq.gz
    """
}