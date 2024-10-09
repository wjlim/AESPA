process calc_dedup_rates {
    label "process_small"
    tag "calculating calc_dedup_rates for ${meta.id}"
    conda NXF_OFFLINE == 'true' ?
        "${params.conda_env_path}/envs/RapidQC_preprocessing":
        "${baseDir}/conf/preprocessing.yml"

    input:
    tuple val(meta), path(forward_read), path(reverse_read)

    output:
    tuple val(meta), path( "${meta.id}.kmer_stats.csv"), emit: dedup_out

    script:
    """
    dedup_rate_predict \\
    -f ${forward_read} \\
    -o ${meta.id}.kmer_stats.csv
    """
}