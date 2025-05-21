#!/bin/bash
read_length=150
target_x=3
output_dir="./subsampling"
read1_out_name="lane1_read1.fastq.gz"
read2_out_name="lane1_read2.fastq.gz"

read1_fastq_gz=""
read2_fastq_gz=""
total_reads=""

print_help() {
    echo "Usage: $0 -i READ1_FASTQ_GZ -a READ2_FASTQ_GZ -t TOTAL_READS -r READ1_OUT_NAME -s READ2_OUT_NAME \
[-l READ_LENGTH:default(${read_length})] [-m TARGET_DEPTH:default(${target_x})] [-o OUTPUT_DIR:default(${output_dir})]"
    echo ""
    echo "This script performs subsampling of paired-end reads to achieve the desired coverage of the human genome using seqtk."
    echo ""
    echo "Options:"
    echo "  -i READ1_FASTQ_GZ      Path to the first paired-end FASTQ file."
    echo "  -a READ2_FASTQ_GZ      Path to the second paired-end FASTQ file."
    echo "  -t TOTAL_READS         Total number of reads in the input files."
    echo "  -r READ1_OUT_NAME      Output name for the first paired-end FASTQ file."
    echo "  -s READ2_OUT_NAME      Output name for the second paired-end FASTQ file."
    echo "  -l READ_LENGTH         Average length of the reads. Default is 150."
    echo "  -m TARGET_DEPTH        Targeted depth. Default is 3."
    echo "  -o OUTPUT_DIR          Output directory for the subsampled files. Default is ${output_dir}."
    echo ""
    echo "Example:"
    echo "  $0 -t 245569065 -i /path/to/read1.fastq.gz -a /path/to/read2.fastq.gz -r sub_read1.fastq.gz -s sub_read2.fastq.gz -o /path/to/output/dir"
}

while getopts ":h:o:i:a:t:l:m:r:s:" opt; do
    case $opt in
        h)
            print_help
            exit 0
            ;;
        o)
            output_dir=$OPTARG
            ;;
        i)
            read1_fastq_gz=$OPTARG
            ;;
        a)
            read2_fastq_gz=$OPTARG
            ;;
        t)
            total_reads=$OPTARG
            ;;
        l)
            read_length=$OPTARG
            ;;
        m)
            target_x=$OPTARG
            ;;
        r)
            read1_out_name=$OPTARG
            ;;
        s)
            read2_out_name=$OPTARG
            ;;
        \?)
            echo "Invalid option: -$OPTARG" >&2
            print_help
            exit 1
            ;;
        :)
            echo "Option -$OPTARG requires an argument." >&2
            print_help
            exit 1
            ;;
    esac
done

if [ -z "$read1_fastq_gz" ] || [ -z "$read2_fastq_gz" ] || [ -z "$total_reads" ]; then
    echo "Error: -i, -a, -t options are required." >&2
    print_help
    exit 1
fi

genome_size=3000000000
total_bp_needed=$(echo "${target_x} * ${genome_size}" | bc)
current_coverage=$(echo "scale=2; ${total_reads} * ${read_length} / ${genome_size}" | bc)
subsampling_ratio=$(echo "scale=2; ${total_bp_needed} / (${total_reads} * ${read_length})" | bc)
subsampled_reads=$(echo "scale=2; ${total_reads} * ${subsampling_ratio}"| bc)

if (( $(echo "${subsampling_ratio} > 0 && ${subsampling_ratio} <= 0.5" | bc -l) )); then
    seqtk sample -s100 ${read1_fastq_gz} ${subsampling_ratio} | gzip > ${read1_out_name} &
    seqtk sample -s100 ${read2_fastq_gz} ${subsampling_ratio} | gzip > ${read2_out_name}
else
    echo -e "[$(date +%Y-%m-%d\ %H:%M:%S)] SKIP: Subsampling: It is unavailable for subsampling because the sampling ratio was over 50%. Subsampling ratio : ${subsampling_ratio}The raw data will be symbolic linked into the subsampling dir" >&2
    ln -s $(readlink -f ${read1_fastq_gz}) ${read1_out_name}
    ln -s $(readlink -f ${read2_fastq_gz}) ${read2_out_name}
fi

echo -e "Subsampling ratio\tGenome_size\tTarget_depth\tRead_length\tnumber_of_sampled_reads\n${subsampling_ratio}\t${genome_size}\t${target_x}\t${read_length}\t${subsampled_reads}" > ${output_dir}/subsampler.simple_stat.txt
