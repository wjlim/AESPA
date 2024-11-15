process sample_sqs_calc {
    label "process_low"
    tag "SQS calculation for ${meta.sample}"

    input:
    tuple val(meta), path(forward_read), path(reverse_read)

    output:
    tuple val(meta), path("${meta.sample}_1.fq_stats.csv"), path("${meta.sample}_2.fq_stats.csv"), emit: sqs_file_ch
    
    script:
    """
    sqs_calc ${forward_read} -o ${meta.sample}_1.fq_stats.csv &
    sqs_calc ${reverse_read} -o ${meta.sample}_2.fq_stats.csv
    """
}