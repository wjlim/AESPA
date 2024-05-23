#!/bin/bash
root_path=/lustre2/Analysis/BI/WholeGenomeReSeq/AN00019230/VA8P_WGS_2/20240517_227GF2LT4_3
sample_id=$(basename $(dirname $root_path))
output_dir=$root_path/AESPA

mkdir -p $output_dir
forward_read=$(find ${root_path}/Fastq/ -type f -regextype posix-extended -regex ".*/${sample_id}_(R1|1)\.fastq\.gz")
reverse_read=$(find ${root_path}/Fastq/ -type f -regextype posix-extended -regex ".*/${sample_id}_(R2|2)\.fastq\.gz")

echo "{
    \"raw_forward_input\": \"${forward_read}\",
    \"raw_reverse_input\": \"${reverse_read}\",
    \"sample_sheet\": \"${root_path}/SampleSheet.csv\",
    \"order_info\": \"${root_path}/OrderInfo.txt\",
    \"sample_id\": \"${sample_id}\",
    \"result_dir\": \"${output_dir}\"
}" > ${output_dir}/${sample_id}.AESPA.input.json
