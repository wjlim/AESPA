process estimate_total_read {
    label "process_single"
    tag "Estimating number of total reads to subsample for ${meta.order}.${meta.sample}.${meta.fc_id}.L00${meta.lane}"

    input:
    tuple val(meta), path(forward_read), path(reverse_read)

    output:
    tuple val(meta), path('estimate_total_reads.csv'), emit:ch_total_reads

    script:
    // sequence + quality lines : ~300 characters per read
    def avg_read_size = 300

    """
    fastq="${forward_read}"
    file_size=\$(stat -c %s \$(readlink -f \${fastq}))
    #compression efficiency : 4 times
    uncompressed_file_size=\$(echo "\${file_size} * 4"|bc)
    total_lines=\$(echo "\${uncompressed_file_size} / ${avg_read_size}"|bc)
    #for Paired-end reads
    echo "\${total_lines} * 2" | bc > estimate_total_reads.csv
    """
}