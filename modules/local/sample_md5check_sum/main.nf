process sample_md5check_sum {
    label "process_local"
    tag "MD5 check for ${meta.sample}"

    input:
    tuple val(meta), path(forward_read), path(reverse_read)

    output:
    tuple val(meta), path( "*.md5")

    script:
    """
    md5sum ${forward_read} > ${meta.sample}.md5
    md5sum ${reverse_read} >> ${meta.sample}.md5
    """
}