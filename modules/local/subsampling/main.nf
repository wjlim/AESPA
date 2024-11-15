process subsampling {
    label "process_low"
    tag "subsampling for ${meta.order}.${meta.sample}.${meta.fc_id}.L00${meta.lane}"
    conda NXF_OFFLINE == 'true' ?
        "${params.conda_env_path}/envs/RapidQC_preprocessing":
        "${baseDir}/conf/preprocessing.yml"

    input:
    tuple val(meta), path(forward_read), path(reverse_read), path(total_read)

    output:
    tuple val(meta), path("${meta.id}_raw_data/"), emit: processed_dir
    tuple val(meta), path("${meta.id}_raw_data/lane1_read1.fastq.gz"), path("${meta.id}_raw_data/lane1_read2.fastq.gz"), emit: ch_sub_samplesheet
    tuple val(meta), path("ratio.csv"), emit: ch_ratio_file
    tuple val(meta), path("subsampling_flag.txt"), emit: ch_subsampling_flag

    script:
    def target_x = params.target_x ?: 5
    def read_length = 151
    def genome_size = 3000000000
    """
    #!/bin/bash
    set -e
    mkdir -p ${meta.id}_raw_data/

    read1_out_name="${meta.id}_raw_data/lane1_read1.fastq.gz"
    read2_out_name="${meta.id}_raw_data/lane1_read2.fastq.gz"
    output_dir="${meta.id}_raw_data"
    total_read=\$(cat ${total_read})
    total_bp_needed=\$(echo "${target_x} * ${genome_size}" | bc)
    current_coverage=\$(echo "scale=2; \${total_read} * ${read_length} / ${genome_size}" | bc)
    subsampling_ratio=\$(echo "scale=2; \${total_bp_needed} / (\${total_read} * ${read_length})" | bc)
    subsampled_reads=\$(echo "scale=2; \${total_read} * \${subsampling_ratio}"| bc)
    
    {
        echo "total_read,current_cov,target_x,genome_size,subsampling_ratio"
        echo "\${total_read},\${current_coverage},${target_x},${genome_size},\${subsampling_ratio}"
    } > ratio.csv

    # Update meta.subsampling based on subsampling_ratio
    if (( \$(echo "\${subsampling_ratio} > 0 && \${subsampling_ratio} <= 0.6" | bc -l) )); then
        echo "true" > subsampling_flag.txt
        seqtk sample -s100 ${forward_read} \${subsampling_ratio} | gzip > \${read1_out_name} &
        seqtk sample -s100 ${reverse_read} \${subsampling_ratio} | gzip > \${read2_out_name}
        wait
    else
        echo "false" > subsampling_flag.txt
        ln -s \$(readlink -f ${forward_read}) \${read1_out_name}
        ln -s \$(readlink -f ${reverse_read}) \${read2_out_name}
    fi
    """
}