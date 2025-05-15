process calc_dedup_rates {
    label "process_small"
    tag "calculating dedup rates for ${meta.prefix}"
    container 'wjlim/aespa-preprocessing'
    conda (params.conda_env_path ? "${params.conda_env_path}/preprocessing" : "${moduleDir}/environment.yml")

    input:
    tuple val(meta), path(forward_read), path(reverse_read)

    output:
    tuple val(meta), path( "${meta.id}.kmer_stats.csv"), emit: dedup_out

    script:
    """
    if [ "${meta.subsampling}" == "true" ]; then
        dedup_rate_predict \\
        -f ${forward_read} \\
        -o ${meta.id}.kmer_stats.csv
    else
        touch ${meta.id}.kmer_stats.csv
    fi
    """
}
