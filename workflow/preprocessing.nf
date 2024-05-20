#!/usr/bin/env nextflow

workflow preprocessing {
    take:
    input_ch

    main:
    md5check_sum(input_ch)
    sqs_calc(input_ch)
    calc_fastqc(input_ch)
    estimate_total_read(input_ch)
    subsampling(input_ch, estimate_total_read.out)
    calc_dedup_rates(input_ch)
    
    emit:
    processed_dir = subsampling.out.preprocess_dir
    kmer_stats = calc_dedup_rates.out.dedup_out
    sqs_file = sqs_calc.out
}

process md5check_sum {
    label "process_local"
    publishDir "${output_dir}/Fastq", mode: "copy"
    tag "MD5 check for ${sample_id}"


    input:
    tuple val(sample_id), path(forward_read), path(reverse_read), path(output_dir)

    output:
    path "*.md5"

    script:
    """
    md5sum ${forward_read} > ${sample_id}.md5
    md5sum ${reverse_read} >> ${sample_id}.md5
    """
}

process sqs_calc {
    label "process_medium"

    publishDir "${output_dir}/Fastq", mode: 'copy'
    publishDir "${output_dir}/stat_outputs", mode: 'copy'
    tag "SQS calculation for ${sample_id}"

    input:
    tuple val(sample_id), path(forward_read), path(reverse_read), path(output_dir)

    output:
    path '*.sqs'

    script:
    """
    sqs_generate.py \\
        -f ${forward_read} \\
        -r ${reverse_read} \\
        -o ${sample_id}.sqs \\
        -s ${sample_id} \\
        -t ${task.cpus}
    """
}

process calc_fastqc {
    label "process_low"
    conda "${baseDir}/workflow/preprocessing.yml"
    tag "FastQC analysis for ${sample_id}"
    publishDir "${output_dir}/Fastq/Fastqc", mode: 'copy'

    input:
    tuple val(sample_id), path(forward_read), path(reverse_read), path(output_dir)

    output:
    path 'Fastqc/*.zip'
    path 'Fastqc/*.html'

    script:
    """
    mkdir -p Fastqc/
    fastqc -t 8 ${forward_read} ${reverse_read} -o Fastqc/
    """
}

process estimate_total_read {
    label "process_single"
    tag "Estimating number of total reads for subsampling"
    input:
    tuple val(sample_id), path(forward_read), path(reverse_read), path(output_dir)

    output:
    stdout

    script:
    """
    fastq="${forward_read}"
    file_size=\$(stat -c %s \$(readlink -f \${fastq}))
    #compression efficiency : 4 times
    uncompressed_file_size=\$(echo "\${file_size} * 4"|bc)
    #sequence + quality lines : ~300 characters per read
    avg_read_size=300
    total_lines=\$(echo "\${uncompressed_file_size} / \${avg_read_size}"|bc)
    #for Paired-end reads
    echo "\${total_lines} * 2 "| bc
    """
}

process subsampling {
    label "process_low"
    tag "3X subsampling for ${sample_id}"
    conda "${baseDir}/workflow/preprocessing.yml"
    // publishDir "${output_dir}", mode: 'copy'

    input:
    tuple val(sample_id), path(forward_read), path(reverse_read), path(output_dir)
    val total_read

    output:
    path "preprocessed_raw_data/*.gz", emit: preprocess_files
    path "preprocessed_raw_data", emit: preprocess_dir

    script:
    """
    mkdir -p preprocessed_raw_data
    subsampler.sh \\
    -i ${forward_read} \\
    -a ${reverse_read} \\
    -r ./preprocessed_raw_data/lane1_read1.fastq.gz \\
    -s ./preprocessed_raw_data/lane1_read2.fastq.gz \\
    -o ./preprocessed_raw_data \\
    -t ${total_read}
    """
}

process calc_dedup_rates {
    label "process_small"
    tag "calculating calc_dedup_rates for ${sample_id}"
    publishDir "${output_dir}", mode: 'copy'
    conda "${baseDir}/workflow/preprocessing.yml"

    input:
    tuple val(sample_id), path(forward_read), path(reverse_read), path(output_dir)

    output:
    path "${sample_id}.kmer_stats.csv", emit: dedup_out

    script:
    """
    kmer_processor \\
    -f ${forward_read} \\
    -o ${sample_id}.kmer_stats.csv
    """
}
