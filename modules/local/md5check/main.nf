process md5check_sum {
    label "process_single"

    tag "MD5 check for ${meta.order}.${meta.sample}.${meta.fc_id}.L00${meta.lane}"

    input:
    tuple val(meta), path(forward_read), path(reverse_read)

    output:
    tuple val(meta), path( "*.md5")

    script:
    """
    md5sum ${forward_read} > ${meta.id}.md5
    md5sum ${reverse_read} >> ${meta.id}.md5
    """
}