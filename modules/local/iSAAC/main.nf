process iSAAC_alignment {
    label "process_high"
    tag "iSAAC_alignment for ${meta.id}"
    // publishDir "${params.outdir}/${meta.sample}/${params.prefix}", mode: 'copy'
    conda NXF_OFFLINE == 'true' ?
        "${params.conda_env_path}/envs/iSAAC_align":
        "${baseDir}/conf/iSAAC_pipeline.yml"

    input:
    tuple val(meta), path(preprocessed_dir), path(converted_sample_sheet), path(reference_fasta), path(reference_fai), path(reference_dict)
    
    output:
    tuple val(meta), path("IsaacAlignment/Projects/${meta.order}/${meta.id}/sorted.bam"), path("IsaacAlignment/Projects/${meta.order}/${meta.id}/sorted.bam.bai"), emit: ch_bam
    
    script:
    def memoryValue = task.memory.toGiga()
    """
    iSAAC_temp=\$(mktemp -d)
    isaac-align \\
    -r ${reference_fasta} \\
    --memory-limit ${memoryValue} \\
    -j ${task.cpus} \\
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