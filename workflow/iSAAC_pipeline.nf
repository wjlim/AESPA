#!/usr/bin/env nextflow

workflow iSAAC_alignment_workflow {
    take:
    preprocess_ch
    ref_ch

    main:
    sample_sheet_convert_for_iSAAC(preprocess_ch)
    iSAAC_alignment(preprocess_ch, ref_ch, sample_sheet_convert_for_iSAAC.out)

    emit:
    iSAAC_alignment.out
}

process sample_sheet_convert_for_iSAAC {
    tag "Converting sample sheet"
    label "process_local"

    input:
    tuple val(meta), path(preprocessed_dir)

    output:
    path '*.csv'

    script:
    """    
    awk 'BEGIN { FS=OFS="," }
        NR == 1 {
            \$5 = substr(\$5, 1, length(\$5)-4)
            print
        }
        NR == 2 {
            \$2 = 1
            \$5 = ""
            split(\$8, a, "-")
            \$8 = a[1] "-" a[4]
            print
        }' ${meta.sample_sheet_path} > iSAAC_sample_sheet.csv
    """
}

process iSAAC_alignment {
    label "process_medium"
    tag "iSAAC_alignment for ${meta.id}"
    conda "${baseDir}/workflow/iSAAC_pipeline.yml"
    publishDir "${meta.result_dir}", mode: "copy"

    input:
    tuple val(meta), path(preprocessed_dir)
    tuple path(reference_fasta), path(reference_fai), path(reference_dict)
    path converted_sample_sheet

    output:
    tuple val(meta), path("IsaacAlignment/Projects/*/*/sorted.bam"), path("IsaacAlignment/Projects/*/*/sorted.bam.bai")
    
    script:
    def iSAAC_memory = "${task.memory}".replaceAll("\\D+", "")
    """
    iSAAC_temp=\$(mktemp -d)
    isaac-align \\
    -r ${reference_fasta} \\
    --memory-limit ${iSAAC_memory} \\
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
