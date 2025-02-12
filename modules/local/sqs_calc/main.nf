process sqs_calc {
    label "process_single"
    tag "SQS calculation for ${meta.order}.${meta.sample}.${meta.fc_id}.L00${meta.lane}"

    input:
    tuple val(meta), path(forward), path(reverse)

    output:
    tuple val(meta), path("*_1.fq_stats.csv"), path("*_2.fq_stats.csv"), emit: sqs_file_ch
    script:
    """
    set -e
    touch ${meta.id}_1.fq_stats.csv
    sqs_calc ${forward} -o ${meta.id}_1.fq_stats.csv  &
    sqs_calc ${reverse} -o ${meta.id}_2.fq_stats.csv
    """
}