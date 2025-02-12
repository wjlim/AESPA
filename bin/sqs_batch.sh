#!/bin/bash

fastq1=$1
fastq2=$2
prefix=${fastq1%.fastq.gz}
SQS_PATH=/mmfs1/lustre2/BI_Analysis/bi2/AESPA/bin

if [ $# == 2 ]; then
    ${SQS_PATH}/sqs_calc ${fastq1} -o ${prefix}_1.fq_stats.csv &
    ${SQS_PATH}/sqs_calc ${fastq2} -o ${prefix}_2.fq_stats.csv &
    wait
    ${SQS_PATH}/sqs_merge.py \
        --sample_name ${prefix} \
        --input_file1 ${prefix}_1.fq_stats.csv \
        --input_file2 ${prefix}_2.fq_stats.csv \
        --output_file ${prefix}.sqs
elif [ $# == 1 ]; then
    ${SQS_PATH}/sqs_calc ${fastq1} -o ${prefix}_1.fq_stats.csv -t sqs -n ${prefix}
else
    echo "Usage: $0 <fastq1> <fastq2>"
    exit 1
fi
