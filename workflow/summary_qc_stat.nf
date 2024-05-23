#!/usr/bin/env nextflow

workflow make_qc_summary {
    take:
    filtered_vcf_ch
    sqs_file
    kmer_out
    flagstat_out
    picard_insertsize
    GATK_DOC
    freemix_out
    doc_distance_out_file

    main:
    summary_qc(
        filtered_vcf_ch,
        sqs_file,
        kmer_out,
        flagstat_out,
        picard_insertsize,
        GATK_DOC,
        freemix_out,
        doc_distance_out_file
    )
}

process summary_qc {
    label "process_single"
    publishDir "${meta.result_dir}", mode: "copy"
    conda "${baseDir}/workflow/preprocessing.yml"
    
    input:
    tuple val(meta), path(out_vcf)
    path sqs_file
    path kmer_out
    path flagstat_out
    path picard_insertsize
    path GATK_DOC
    path freemix_out
    path doc_distance_out_file

    output:
    path "*.QC.summary"

    script:
    """
    summary_stat.py  \\
        -s ${sqs_file} \\
        -k ${kmer_out} \\
        -f ${flagstat_out} \\
        -p ${picard_insertsize} \\
        -d ${GATK_DOC} \\
        -i ${doc_distance_out_file} \\
        -x ${freemix_out} \\
        -v ${out_vcf} \\
        -a ${meta.order_num} \\
        -l ${meta.lib_group} \\
        -o ${meta.id}.QC.summary
    """
}