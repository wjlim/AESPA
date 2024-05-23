#!/bin/bash

# Wrapper script to call the Nextflow pipeline

# Function to print help message
print_help() {
    echo "Usage: $0 -s <path> -f <path> -r <path> -o <path>"
    echo ""
    echo "Parameters:"
    echo "  -s    Path to the sample sheet file (CSV format)."
    echo "  -f    Path to the forward read file."
    echo "  -r    Path to the reverse read file."
    echo "  -o    Directory where results will be stored."
    echo ""
    echo "Example:"
    echo "  $0 -s /path/to/SampleSheet.csv -f /path/to/forward.fastq -r /path/to/reverse.fastq -o /path/to/results"
}

# Check if the correct number of arguments are provided
if [ "$#" -eq 0 ]; then
    print_help
    exit 1
fi

# Parse command line arguments using getopt
TEMP=$(getopt -o s:f:r:o: --long sample_sheet:,forward_read:,reverse_read:,result_dir: -n 'call_nextflow_pipeline' -- "$@")
if [ $? != 0 ]; then
    echo "Error parsing arguments"
    print_help
    exit 1
fi

eval set -- "$TEMP"

while true; do
    case "$1" in
        -s | --sample_sheet ) sample_sheet="$2"; shift 2 ;;
        -f | --forward_read ) forward_read="$2"; shift 2 ;;
        -r | --reverse_read ) reverse_read="$2"; shift 2 ;;
        -o | --result_dir ) result_dir="$2"; shift 2 ;;
        -- ) shift; break ;;
        * ) break ;;
    esac
done

# Check if all required parameters are provided
if [ -z "$sample_sheet" ] || [ -z "$forward_read" ] || [ -z "$reverse_read" ] || [ -z "$result_dir" ]; then
    echo "Error: Missing required parameters."
    print_help
    exit 1
fi

CONDA_BASE=$(conda info --base)
source "$CONDA_BASE/etc/profile.d/conda.sh"

# Call the Nextflow pipeline
src_dir=$(dirname $(readlink -f $0))
working_dir=${result_dir}/work
nf_temp=${result_dir}/temp
export NXF_WORK=${working_dir}
export NXF_TEMP=${nf_temp}
export NXF_CACHE_DIR=${working_dir}/.nextflow
export NXF_LOG_FILE=${working_dir}/.nextflow.log
export NXF_PLUGINS_DIR=${working_dir}/plr
export NXF_HOME=${working_dir}/.nextflow
# export NXF_OFFLINE=true

mkdir -p ${result_dir}
mkdir -p ${working_dir}
mkdir -p ${nf_temp}

nextflow run ${src_dir}/main.nf \
    -profile sge_conda_env \
    --sample_sheet "${sample_sheet}" \
    --forward_read "${forward_read}" \
    --reverse_read "${reverse_read}" \
    --result_dir "${result_dir}" \
    -with-report "${result_dir}/reports/nf_out.report.html" \
    -with-dag "${result_dir}/reports/flowchart.png" \
    -with-timeline "${result_dir}/reports/nf_out.timeline.report.html" \
    -with-trace "${result_dir}/reports/nf_out.trace.txt" \
    -bg \
    -resume &> "${result_dir}/runLog.txt"
