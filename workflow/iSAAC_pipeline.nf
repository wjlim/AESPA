#!/usr/bin/env nextflow

workflow iSAAC_alignment_workflow {
    take:
    input_ch
    ref_ch
    sample_sheet
    processed_dir

    main:
    sample_sheet_convert_for_iSAAC(sample_sheet)
    iSAAC_alignment(input_ch, ref_ch, sample_sheet_convert_for_iSAAC.out, processed_dir)
    
    emit:
    sorted_bam = iSAAC_alignment.out.sorted_bam
    sorted_bai = iSAAC_alignment.out.sorted_bai
}

process sample_sheet_convert_for_iSAAC {
    tag "Converting sample sheet"
    label "process_local"

    input:
    path sample_sheet

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
        }' ${sample_sheet} > iSAAC_sample_sheet.csv
    """
}

process iSAAC_alignment {
    label "process_high"
    tag "iSAAC_alignment for ${sample_id}"
    conda "${baseDir}/workflow/iSAAC_pipeline.yml"
    publishDir "${output_dir}", mode: "copy"

    input:
    tuple val(sample_id), path(forward_read), path(reverse_read), path(output_dir)
    tuple path(reference_fasta), path(reference_fai), path(reference_dict)
    path converted_sample_sheet
    path processed_dir

    output:
    path "IsaacAlignment/Projects/*/*/sorted.bam", emit: sorted_bam
    path "IsaacAlignment/Projects/*/*/sorted.bam.bai", emit: sorted_bai
    
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
    -b ${processed_dir} \\
    --base-calls-format fastq-gz \\
    --sample-sheet ${converted_sample_sheet} \\
    --bam-gzip-level 7 \\
    --verbosity 1
    """
}
