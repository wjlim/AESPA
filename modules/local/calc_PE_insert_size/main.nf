process calc_PE_insert_size {
    label "process_low"
    tag "Picard insertsize calculation for ${meta.id}"
    conda (params.conda_env_path ? "${params.conda_env_path}/picard_env" : "${moduleDir}/environment.yml")

    input:
    tuple val(meta), path(inbam), path(inbai)

    output:
    tuple val(meta), path("${meta.id}.insert_size_metrics")

    script:
    """
    picard \\
        CollectInsertSizeMetrics \\
        H=insert_size_hist.pdf \\
        I=${inbam} \\
        O=${meta.id}.insert_size_metrics \\
        VALIDATION_STRINGENCY=LENIENT
    """
}
