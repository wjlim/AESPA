process calc_genome_coverage {
    label "process_single"
    tag "Get genome cov for ${meta.id}"
    conda NXF_OFFLINE == 'true' ?
        "${params.conda_env_path}/envs/calc_bam_stat":
        "${baseDir}/conf/bam_stat_calculation.yml"

    input:
    tuple val(meta), path(out_bam), path(out_bai)

    output:
    tuple val(meta), path("*.genomecov")

    script:
    """
    bedtools \\
        genomecov \\
        -ibam ${out_bam} \\
        > ${meta.id}.genomecov
    """
}