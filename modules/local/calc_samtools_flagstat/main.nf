process calc_samtools_flagstat {
    label "process_single"
    tag "samtools flagstats for ${meta.order}.${meta.sample}.${meta.fc_id}.L00${meta.lane}"
    conda NXF_OFFLINE == 'true' ?
        "${params.conda_env_path}/envs/calc_bam_stat":
        "${baseDir}/conf/bam_stat_calculation.yml"

    input:
    tuple val(meta), path(out_bam), path(out_bai)

    output:
    tuple val(meta), path( "*.flagstat")

    script:
    """
    samtools_flagstat.py ${out_bam} > ${meta.id}.flagstat
    """
}
