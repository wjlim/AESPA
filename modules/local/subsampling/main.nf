process subsampling {
    label "process_single"
    tag "subsampling for ${meta.prefix}"
    container 'wjlim/aespa-preprocessing'
    conda (params.conda_env_path ? "${params.conda_env_path}/preprocessing" : "${moduleDir}/environment.yml")

    input:
    tuple val(meta), path(forward_read), path(reverse_read)

    output:
    tuple val(meta), path("${meta.id}_raw_data/"), emit: processed_dir
    tuple val(meta), path("${meta.id}_raw_data/lane1_read1.fastq.gz"), path("${meta.id}_raw_data/lane1_read2.fastq.gz"), emit: ch_sub_samplesheet

    script:
    """
    #!/bin/bash
    set -e
    mkdir -p ${meta.id}_raw_data/

    read1_out_name="${meta.id}_raw_data/lane1_read1.fastq.gz"
    read2_out_name="${meta.id}_raw_data/lane1_read2.fastq.gz"

    if [ "${meta.subsampling}" = "true" ]; then
        seqtk sample -s100 ${forward_read} ${meta.sub_ratio} | gzip > \${read1_out_name} &
        seqtk sample -s100 ${reverse_read} ${meta.sub_ratio} | gzip > \${read2_out_name}
        wait
    else
        ln -s \$(readlink -f ${forward_read}) \${read1_out_name}
        ln -s \$(readlink -f ${reverse_read}) \${read2_out_name}
    fi
    """
}
