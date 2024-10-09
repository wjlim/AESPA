process sqs_calc {
    label "process_low"
    tag "SQS calculation for ${meta.id}"

    input:
    tuple val(meta), path(forward), path(reverse)

    output:
    tuple val(meta), path("*_1.fq_stats.csv"), path("*_2.fq_stats.csv"), emit: sqs_file_ch
    script:
    """
    sqs_calc ${forward} -o ${meta.id}_1.fq_stats.csv  &
    sqs_calc ${reverse} -o ${meta.id}_2.fq_stats.csv
    """
}