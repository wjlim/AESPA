process SEXDETERRMINE {
    tag "$meta.id"
    label 'process_single'
    conda NXF_OFFLINE == 'true' ?
        "${params.conda_env_path}/envs/sexdeterrmine":
        "${moduleDir}/environment.yml"

    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/sexdeterrmine:1.1.2--hdfd78af_1':
        'biocontainers/sexdeterrmine:1.1.2--hdfd78af_1' }"

    input:
    tuple val(meta), path(out_bam), path(out_bai), path(ref), path(ref_fai), path(ref_dict)

    output:
    tuple val(meta), path("*.json"), emit: json
    tuple val(meta), path("*.tsv") , emit: tsv

    script:
    def args = task.ext.args ?: ''
    def prefix = task.ext.prefix ?: "${meta.id}"

    """
    sexdeterrmine \\
        -I $depth \\
        $sample_list \\
        $args \\
        > ${prefix}.tsv
    """
}