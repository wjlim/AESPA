process iSAAC_alignment {
    label "process_medium"
    tag "iSAAC_alignment for ${meta.order}.${meta.sample}.${meta.fc_id}.L00${meta.lane}"
    // publishDir "${params.outdir}/${meta.sample}/${params.prefix}", mode: 'copy'
    conda NXF_OFFLINE == 'true' ?
        "${params.conda_env_path}/envs/iSAAC_align":
        "${baseDir}/conf/iSAAC_pipeline.yml"

    input:
    tuple val(meta), path(preprocessed_dir), path(converted_sample_sheet), path(reference_fasta), path(reference_fai), path(reference_dict)
    
    output:
    tuple val(meta), path("IsaacAlignment/Projects/${meta.order}/*/sorted.bam"), path("IsaacAlignment/Projects/${meta.order}/*/sorted.bam.bai"), emit: ch_bam
    
    script:
    // def memoryValue = task.memory.toGiga()
    // def cpus = Math.max(1, int(memoryValue / 6)) // Ensure at least 1 CPU is allocated
    """
    iSAAC_temp=\$(mktemp -d)
    isaac-align \\
    -r ${reference_fasta} \\
    --memory-limit 192 \\
    -j 32 \\
    --base-quality-cutoff 15 \\
    --keep-duplicates 1 \\
    --variable-read-length 1 \\
    --ignore-missing-bcls 1 \\
    --ignore-missing-filters 1 \\
    --realign-gaps no \\
    --cleanup-intermediary 1 \\
    --default-adapters AGATCGGAAGAGC*,*GCTCTTCCGATCT \\
    --bam-exclude-tags none \\
    --memory-control warning \\
    --output-directory IsaacAlignment \\
    --temp-directory \$iSAAC_temp \\
    -b ${preprocessed_dir} \\
    --base-calls-format fastq-gz \\
    --sample-sheet ${converted_sample_sheet} \\
    --bam-gzip-level 7 \\
    --verbosity 1
    """
}