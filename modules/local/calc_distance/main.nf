process calc_distance {
    label "process_single"
    tag "depth of coverage distance for ${meta.id}"
    conda (params.conda_env_path ? "${params.conda_env_path}/calc_bam_stat" : "${moduleDir}/environment.yml")

    input:
    tuple val(meta), path(out_bam), path(out_bai), path(ref), path(ref_fai), path(ref_dict), path(genome_coverage)

    output:
    tuple val(meta), path("${meta.id}.depthofcov.stat")

    script:
    """
    DOC_distance.py \\
        ${genome_coverage} \\
        > ${meta.id}.depthofcov.stat
    """
}
