process estimate_total_read {
    label "process_single"
    tag "Estimating number of total reads to subsample for ${meta.prefix}"
    container 'wjlim/aespa-preprocessing'
    conda (params.conda_env_path ? "${params.conda_env_path}/preprocessing" : "${moduleDir}/environment.yml")

    input:
    tuple val(meta), path(forward_read), path(reverse_read)

    output:
    tuple val(meta), stdout, emit: ch_total_reads

    script:
    def target_x = params.target_x ?: 5
    def read_length = 151
    def genome_size = 3000000000
    def avg_read_size = 300
    """
    #!/bin/bash
    fastq="${forward_read}"
    file_size=\$(stat -c %s \$(readlink -f \${fastq}))
    uncompressed_file_size=\$(echo "\${file_size} * 4"|bc)
    total_lines=\$(echo "\${uncompressed_file_size} / ${avg_read_size}"|bc)
    total_reads=\$(echo "\${total_lines} * 2" | bc)

    total_bp_needed=\$(echo "${target_x} * ${genome_size}" | bc)
    current_bp=\$(echo "\${total_reads} * ${read_length}" | bc)

    sub_ratio=\$(echo "scale=4; \${total_bp_needed} / \${current_bp}" | bc) || sub_ratio=1.0

    echo "\${sub_ratio}"
    """
}
