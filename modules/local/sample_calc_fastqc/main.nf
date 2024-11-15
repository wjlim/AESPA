process sample_calc_fastqc {
    label "process_medium"
    conda NXF_OFFLINE == 'true' ?
        "${params.conda_env_path}/envs/RapidQC_preprocessing":
        "${baseDir}/conf/preprocessing.yml"
    tag "FastQC analysis for ${meta.sample}"

    input:
    tuple val(meta), path(forward_read), path(reverse_read)

    output:
    tuple val(meta), path('Fastqc/*.zip'), emit: fastqc_zip
    tuple val(meta), path('Fastqc/*.html'), emit: fastqc_html
    // tuple val(meta), path(forward_read), path(reverse_read), emit: ch_test_files

    script:
    def wgs_dest_path = params.wgs_dest_path
    """
    mkdir -p Fastqc/
    fastqc -t ${task.cpus} ${forward_read} ${reverse_read} -o Fastqc/
    """
}