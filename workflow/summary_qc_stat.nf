#!/usr/bin/env nextflow

workflow make_qc_summary {
    take:
    sample_id
    order_num
    lib_group
    sqs_file
    kmer_out
    out_vcf
    flagstat_out
    picard_insertsize
    GATK_DOC
    freemix_out
    doc_distance_out_file

    main:
    summary_qc(
        sample_id,
        order_num,
        lib_group,
        sqs_file,
        kmer_out,
        out_vcf,
        flagstat_out,
        picard_insertsize,
        GATK_DOC,
        freemix_out,
        doc_distance_out_file
    )
}

process summary_qc {
    label "process_single"
    publishDir "${input.result_dir}", mode: "copy"
    conda "${baseDir}/workflow/preprocessing.yml"
    
    input:
    val sample_id
    val order_num
    val lib_group
    path sqs_file
    path kmer_out
    path flagstat_out
    path picard_insertsize
    path GATK_DOC
    path freemix_out
    path out_vcf
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
        -a ${order_num} \\
        -l ${lib_group} \\
        -o ${sample_id}.QC.summary
    """
}