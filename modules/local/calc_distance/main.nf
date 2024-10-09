process calc_distance {
    label "process_single"
    tag "depth of coverage distance for ${meta.id}"
    conda NXF_OFFLINE == 'true' ?
        "${params.conda_env_path}/envs/calc_bam_stat":
        "${baseDir}/conf/bam_stat_calculation.yml"

    input:
    tuple val(meta), path(out_bam), path(out_bai)
    tuple val(meta), path( genome_coverage)

    output:
    tuple val(meta), path("${meta.id}.depthofcov.stat")
    
    script:
    """
    DOC_distance.py \\
        ${genome_coverage} \\
        > ${meta.id}.depthofcov.stat
    """
}