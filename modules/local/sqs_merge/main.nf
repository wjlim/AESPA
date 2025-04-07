process sqs_merge {
    label "process_single"
    tag "SQS merge for ${meta.order}.${meta.sample}.${meta.fc_id}.L00${meta.lane}"
    conda NXF_OFFLINE == 'true' ?
        "${params.conda_env_path}/envs/RapidQC_preprocessing":
        "${baseDir}/conf/preprocessing.yml"
    
    input:
    tuple val(meta), path(forward_input), path(reverse_input)

    output:
    tuple val(meta), path("${meta.id}.sqs"), emit: sqs_file

    script:
    """
    sqs_merge.py \
        --sample_name ${meta.id} \
        --input_file1 ${forward_input} \
        --input_file2 ${reverse_input} \
        --output_file ${meta.id}.sqs
    """
}