process sample_sqs_merge {
    label "process_single"
    tag "SQS merge for ${meta.sample}"
    conda NXF_OFFLINE == 'true' ?
        "${params.conda_env_path}/envs/RapidQC_preprocessing":
        "${baseDir}/conf/preprocessing.yml"
    
    input:
    tuple val(meta), path(forward_read), path(reverse_read)

    output:
    tuple val(meta), path('*.sqs'), emit: sqs_file

    script:
    """
    set -e
    touch ${meta.sample}.sqs
    sqs_merge.py \
        --sample_name ${meta.sample} \
        --input_file1 ${forward_read} \
        --input_file2 ${reverse_read} \
        --output_file ${meta.sample}.sqs
    """
}
