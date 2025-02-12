process calc_PE_insert_size {
    label "process_low"
    tag "Picard insertsize calculation for ${meta.order}.${meta.sample}.${meta.fc_id}.L00${meta.lane}"
    conda NXF_OFFLINE == 'true' ?
        "${params.conda_env_path}/envs/picard_env":
        "${baseDir}/conf/bam_stat_calculation.picard.yml"

    input:
    tuple val(meta), path(out_bam), path(out_bai)

    output:
    tuple val(meta), path("*.insert_size_metrics")

    script:
    """
    set -e
    touch ${meta.id}.insert_size_metrics
    /mmfs1/lustre2/BI_Analysis/bi2/anaconda3/envs/picard_env/bin/picard \\
        CollectInsertSizeMetrics \\
        H=insert_size_hist.pdf \\
        I=${out_bam} \\
        O=${meta.id}.insert_size_metrics \\
        VALIDATION_STRINGENCY=LENIENT
    """
}
