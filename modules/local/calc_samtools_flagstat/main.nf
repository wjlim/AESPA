process calc_samtools_flagstat {
    label "process_single"
    tag "samtools flagstats for ${meta.id}"
    conda (params.conda_env_path ? "${params.conda_env_path}/calc_bam_stat" : "${moduleDir}/environment.yml")

    input:
    tuple val(meta), path(out_bam), path(out_bai)

    output:
    tuple val(meta), path( "*.flagstat")

    script:
    """
    set -e
    touch ${meta.id}.flagstat
    samtools_flagstat.py ${out_bam} > ${meta.id}.flagstat
    """
}
