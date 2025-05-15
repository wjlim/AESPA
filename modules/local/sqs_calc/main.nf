process sqs_calc {
    label "process_single"
    tag "SQS calculation for ${meta.prefix}"
    container 'wjlim/aespa-preprocessing'
    conda (params.conda_env_path ? "${params.conda_env_path}/preprocessing" : "${moduleDir}/environment.yml")

    input:
    tuple val(meta), path(forward), path(reverse)

    output:
    tuple val(meta), path("${meta.id}_1.fq_stats.csv"), path("${meta.id}_2.fq_stats.csv"), emit: ch_sqs_file
    tuple val(meta), path("${meta.id}.sqs"), emit: ch_sqs

    script:
    """
    sqs_calc ${forward} -o ${meta.id}_1.fq_stats.csv  &
    sqs_calc ${reverse} -o ${meta.id}_2.fq_stats.csv
    wait
    sqs_merge.py \
        --sample_name ${meta.id} \
        --input_file1 ${meta.id}_1.fq_stats.csv \
        --input_file2 ${meta.id}_2.fq_stats.csv \
        --output_file ${meta.id}.sqs
    """
}
