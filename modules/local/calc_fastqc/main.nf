process calc_fastqc {
    label "process_medium"
    conda NXF_OFFLINE == 'true' ?
        "${params.conda_env_path}/envs/RapidQC_preprocessing":
        "${baseDir}/conf/preprocessing.yml"
    tag "FastQC analysis for ${meta.sample}.${meta.fc_id}.${meta.lane}"

    input:
    tuple val(meta), path(forward_read), path(reverse_read)

    output:
    tuple val(meta), path('Fastqc/*.zip'), emit: fastqc_zip
    tuple val(meta), path('Fastqc/*.html'), emit: fastqc_html

    script:
    """
    mkdir -p Fastqc/
    fastqc -t ${task.cpus} ${forward_read} ${reverse_read} -o Fastqc/
    """
}
