process calc_distance {
    label "process_single"
    tag "depth of coverage distance for ${meta.order}.${meta.sample}.${meta.fc_id}.L00${meta.lane}"
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
    set -e
    DOC_distance.py \\
        ${genome_coverage} \\
        > ${meta.id}.depthofcov.stat
    touch ${meta.id}.depthofcov.sample_summary
    """
}