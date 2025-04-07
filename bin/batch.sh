#!/bin/bash

if [ $# -ne 1 ]; then
    echo "Usage: $0 <Order_number>"
    echo "Example : $0 AN00016813"
    exit 1
fi

order_num=$1

PROJECT_DIR="/lustre2/Analysis/BI/WholeGenomeReSeq/${order_num}"
PROCESSED_DIR_LIST="$PROJECT_DIR/processed_dirs.txt"

# if [ ! -f "$PROCESSED_DIR_LIST" ]; then
#     touch "$PROCESSED_DIR_LIST"
# fi

for dir in $(find "$PROJECT_DIR" -mindepth 2 -maxdepth 2 -type d); do
    demux_path=$(basename "$dir")
    sample_id=$(basename $(dirname "$dir"))

    dir_path="${PROJECT_DIR}/${sample_id}/${demux_path}"

    # if grep -Fxq "$dir_path" "$PROCESSED_DIR_LIST"; then
    #     echo "Skipping processed directory: $dir_path"
    #     continue
    # fi

    confirm_file="${dir_path}/confirm.txt"
    samplesheet_file="${dir_path}/SampleSheet.csv"
    orderinfo_file="${dir_path}/OrderInfo.txt"
    
    if [ ! -f "$confirm_file" ]; then
        confirm_file="/lustre2/Analysis/Project/${order_num}/${demux_path}/${sample_id}/confirm.txt"
    fi
    
    if [ -f "$confirm_file" ] && [ -f "$samplesheet_file" ] && [ -f "$orderinfo_file" ]; then
        analysis_path=$(awk -F'\t' 'NR==2 {print $3}' "$confirm_file")
        fc_id=$(awk -F',' 'NR==2 {print $1}' "$samplesheet_file")
        lane=$(awk -F',' 'NR==2 {print $2}' "$samplesheet_file")
        ref_ver=$(awk -F'\t' 'NR==2 {print $15}' "$orderinfo_file")

        json_file="${sample_id}_${fc_id}.json"
        output_dir=/mmfs1/lustre2/BI_Analysis/wjlim/wgs_pipeline/RapidQC/${order_num}/${sample_id}/${demux_path}
        mkdir -p ${output_dir}
        echo "{
    \"raw_forward_input\": \"${output_dir}/Fastq/${sample_id}_R1.fastq.gz\",
    \"raw_reverse_input\": \"${output_dir}/Fastq/${sample_id}_R2.fastq.gz\",
    \"sample_sheet\": \"${samplesheet_file}\",
    \"order_info\": \"${orderinfo_file}\",
    \"order_num\": \"${order_num}\",
    \"sample_id\": \"${sample_id}\",
    \"fc_id\": \"${demux_path}\",
    \"ref_ver\": \"${ref_ver}\",
    \"max_threads\": 21,
    \"max_memory\": 80,
    \"result_dir\": \"${output_dir}\"
}" > ${output_dir}/${json_file}

        mkdir -p ${output_dir}/Fastq
        mkdir -p ${output_dir}/Fastq/Fastqc
        ln -s $(find ${dir_path}/Fastq/ -type f -regextype posix-extended -regex ".*/${sample_id}_(R1|1)\.fastq\.gz") "${output_dir}/Fastq/${sample_id}_R1.fastq.gz"
        ln -s $(find ${dir_path}/Fastq/ -type f -regextype posix-extended -regex ".*/${sample_id}_(R2|2)\.fastq\.gz") "${output_dir}/Fastq/${sample_id}_R2.fastq.gz"
        cp -n ${dir_path}/Fastq/*.sqs ${output_dir}/Fastq
        cp -n ${dir_path}/Fastq/*.md5 ${output_dir}/Fastq
        cp -n ${dir_path}/Fastq/Fastqc/*.zip ${output_dir}/Fastq/Fastqc
        cp -n ${dir_path}/Fastq/Fastqc/*.html ${output_dir}/Fastq/Fastqc
        echo -e "sh /mmfs1/lustre2/BI_Analysis/wjlim/wgs_pipeline/bin/wgs_qc.sh $(readlink -f ${output_dir}/${json_file})" > ${output_dir}/run.${json_file%.json}.sh
        # qsub -cwd -V -l h_vmem=16G -pe smp 16 -N "${sample_id}_${fc_id}" "wgs_qc.sh $json_file"
        # echo "$dir_path" >> "$PROCESSED_DIR_LIST"
    else
        echo "Required file(s) missing in $dir_path"
    fi
done
