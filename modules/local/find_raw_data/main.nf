process FIND_RAW_DATA {
    label "process_single"
    tag "sample_sheet converting for ${meta.order}.${meta.sample}.${meta.fc_id}.L00${meta.lane}"
    publishDir "${params.outdir}/${meta.sample}/Fastq", mode: "link", overwrite: true
        
    input:
    tuple val(meta), path(samplesheet_dir)

    output:
    tuple val(meta), path("${meta.id}_1.fastq.gz"), path("${meta.id}_2.fastq.gz"), emit: ch_fastqs

    script:
    """
    set -e
    sample_dir="${samplesheet_dir}/${meta.order}/${meta.order}_${meta.sample}"
    if [ ! -d "\$sample_dir" ]; then
        echo "Error: Directory \$sample_dir does not exist" >&2
        exit 1
    fi
    
    # Try to find files with R1/R2 pattern
    r1_file=\$(find "\$sample_dir" -maxdepth 1 -type f -name "${meta.sample}_S*_L00${meta.lane}_R1_*.fastq.gz" | head -n 1)
    r2_file=\$(find "\$sample_dir" -maxdepth 1 -type f -name "${meta.sample}_S*_L00${meta.lane}_R2_*.fastq.gz" | head -n 1)
    
    # If R1/R2 files are not found, try _1/_2 pattern
    if [ -z "\$r1_file" ] || [ -z "\$r2_file" ]; then
        r1_file=\$(find "\$sample_dir" -maxdepth 1 -type f -name "${meta.sample}_S*_L00${meta.lane}_*1.fastq.gz" | head -n 1)
        r2_file=\$(find "\$sample_dir" -maxdepth 1 -type f -name "${meta.sample}_S*_L00${meta.lane}_*2.fastq.gz" | head -n 1)
    fi
    
    # If files are still not found, exit with error
    if [ -z "\$r1_file" ] || [ -z "\$r2_file" ]; then
        echo "Error: Could not find matching R1/R2 or _1/_2 fastq.gz files in \$sample_dir" >&2
        exit 1
    fi
    
    # Create symlinks with consistent naming
    ln -s "\$(readlink -f \$r1_file)" "${meta.id}_1.fastq.gz"
    ln -s "\$(readlink -f \$r2_file)" "${meta.id}_2.fastq.gz"
    
    # Verify that the symlinks were created
    if [ ! -e "${meta.id}_1.fastq.gz" ] || [ ! -e "${meta.id}_2.fastq.gz" ]; then
        echo "Error: Failed to create symlinks for fastq.gz files" >&2
        exit 1
    fi
    """
}