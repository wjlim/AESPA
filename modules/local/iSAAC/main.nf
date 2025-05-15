process iSAAC_alignment {
    label "process_medium"
    tag "iSAAC_alignment for ${meta.id}"
    container 'wjlim/aespa-isaac'
    conda "iSAAC_align"

    input:
    tuple val(meta), path(preprocessed_dir), path(converted_sample_sheet), path(reference_fasta), path(reference_fai), path(reference_dict)

    output:
    tuple val(meta), path("${meta.id}.bam"), path("${meta.id}.bam.bai"), emit: ch_bam

    script:
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
    mv IsaacAlignment/Projects/*/*/sorted.bam ${meta.id}.bam
    mv IsaacAlignment/Projects/*/*/sorted.bam.bai ${meta.id}.bam.bai
    """
}
