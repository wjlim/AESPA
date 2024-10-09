workflow REPORT_PREPARE {
    take:
    ch_merged_samplesheet
    
    main:
    sample_md5check_sum(ch_merged_samplesheet)
    sample_calc_fastqc(ch_merged_samplesheet)
    sample_sqs_calc(ch_merged_samplesheet)
    sample_sqs_merge(sample_sqs_calc.out.sqs_file_ch)
}

process sample_calc_fastqc {
    label "process_medium"
    conda NXF_OFFLINE == 'true' ?
        "${params.conda_env_path}/envs/RapidQC_preprocessing":
        "${baseDir}/conf/preprocessing.yml"
    publishDir "${params.outdir}/${meta.sample}/merge_analysis/Fastq/Fastqc", mode: 'copy'
    tag "FastQC analysis for ${meta.sample}"

    input:
    tuple val(meta), path(forward_read), path(reverse_read)

    output:
    tuple val(meta), path('Fastqc/*.zip'), emit: fastqc_zip
    tuple val(meta), path('Fastqc/*.html'), emit: fastqc_html
    tuple val(meta), path(forward_read), path(reverse_read), emit: ch_test_files

    script:
    def wgs_dest_path = params.wgs_dest_path
    """
    mkdir -p Fastqc/
    fastqc -t ${task.cpus} ${forward_read} ${reverse_read} -o Fastqc/
    """
}

process sample_sqs_calc {
    label "process_low"
    tag "SQS calculation for ${meta.sample}"
    publishDir "${params.outdir}/${meta.sample}/merge_analysis/Fastq", mode: 'copy'

    input:
    tuple val(meta), path(forward_read), path(reverse_read)

    output:
    tuple val(meta), path("${meta.sample}_1.fq_stats.csv"), path("${meta.sample}_2.fq_stats.csv"), emit: sqs_file_ch
    
    script:
    """
    sqs_calc ${forward_read} -o ${meta.sample}_1.fq_stats.csv &
    sqs_calc ${reverse_read} -o ${meta.sample}_2.fq_stats.csv
    """
}

process sample_sqs_merge {
    label "process_single"
    tag "SQS merge for ${meta.sample}"
    publishDir "${params.outdir}/${meta.sample}/merge_analysis/Fastq", mode: 'copy'
    conda NXF_OFFLINE == 'true' ?
        "${params.conda_env_path}/envs/RapidQC_preprocessing":
        "${baseDir}/conf/preprocessing.yml"
    
    input:
    tuple val(meta), path(forward_read), path(reverse_read)

    output:
    tuple val(meta), path('*.sqs'), emit: sqs_file

    script:
    """
    sqs_merge.py \
        --sample_name ${meta.sample} \
        --input_file1 ${forward_read} \
        --input_file2 ${reverse_read} \
        --output_file ${meta.sample}.sqs
    """
}

process sample_md5check_sum {
    label "process_local"
    publishDir "${params.outdir}/${meta.sample}/merge_analysis/Fastq", mode: 'copy'
    tag "MD5 check for ${meta.sample}"

    input:
    tuple val(meta), path(forward_read), path(reverse_read)

    output:
    tuple val(meta), path( "*.md5")

    script:
    """
    md5sum ${forward_read} > ${meta.sample}.md5
    md5sum ${reverse_read} >> ${meta.sample}.md5
    """
}
