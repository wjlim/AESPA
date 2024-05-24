#!/usr/bin/env nextflow

workflow preprocessing {
    take:
    reads

    main:
    md5check_sum(reads)
    sqs_calc(reads)
    calc_fastqc(reads)
    estimate_total_read(reads)
    calc_dedup_rates(reads)
    (processed_dir , processed_files) = subsampling(reads, estimate_total_read.out)

    emit:
    processed_dir
    calc_dedup_rates.out.dedup_out
    sqs_calc.out
}

process md5check_sum {
    label "process_local"
    publishDir "${meta.result_dir}/Fastq", mode: "copy"
    tag "MD5 check for ${meta.id}"


    input:
    tuple val(meta), path(forward_read), path(reverse_read)

    output:
    path "*.md5"

    script:
    """
    md5sum ${forward_read} > ${meta.id}.md5
    md5sum ${reverse_read} >> ${meta.id}.md5
    """
}

process sqs_calc {
    label "process_medium"

    publishDir "${meta.result_dir}/Fastq", mode: 'copy'
    publishDir "${meta.result_dir}/stat_outputs", mode: 'copy'
    tag "SQS calculation for ${meta.id}"

    input:
    tuple val(meta), path(forward_read), path(reverse_read)

    output:
    path "${meta.id}.sqs"

    script:
    """
    # Define the output SQS file path
    sqs_file="${forward_read.getParent()}/${meta.id}.sqs"

    # Check if the SQS file exists
    if [ -f \${sqs_file} ]; then
        # If it exists, copy it to the output directory
        cp \${sqs_file} ./
    else
        # If it does not exist, generate it
        sqs_generate.py \\
            -f ${forward_read} \\
            -r ${reverse_read} \\
            -o ${meta.id}.sqs \\
            -s ${meta.id} \\
            -t ${task.cpus}
    fi
    """
}

process calc_fastqc {
    label "process_low"
    conda "${baseDir}/conf/preprocessing.yml"
    tag "FastQC analysis for ${meta.id}"
    publishDir "${meta.result_dir}/Fastq/Fastqc", mode: 'copy'

    input:
    tuple val(meta), path(forward_read), path(reverse_read)

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
    tuple val(meta), path(forward_read), path(reverse_read)

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
    tag "3X subsampling for ${meta.id}"
    conda "${baseDir}/conf/preprocessing.yml"
    // publishDir "${meta.result_dir}", mode: 'copy'

    input:
    tuple val(meta), path(forward_read), path(reverse_read)
    val total_read

    output:
    tuple val(meta), path("preprocessed_raw_data/")
    path "preprocessed_raw_data/*.gz"

    script:
    """
    mkdir -p preprocessed_raw_data/
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
    tag "calculating calc_dedup_rates for ${meta.id}"
    publishDir "${meta.result_dir}", mode: 'copy'
    conda "${baseDir}/conf/preprocessing.yml"

    input:
    tuple val(meta), path(forward_read), path(reverse_read)

    output:
    path "${meta.id}.kmer_stats.csv", emit: dedup_out

    script:
    """
    dedup_rate_predict \\
    -f ${forward_read} \\
    -o ${meta.id}.kmer_stats.csv
    """
}
