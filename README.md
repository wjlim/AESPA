# AESPA: Accurate and Efficient Sub-sampling Pipeline for WGS analysis

## Overview
This pipeline is designed to perform quality control (QC) for whole genome sequencing (WGS) data by conducting 3x subsampling. 
The entire workflow is modularized using Nextflow.

## 🌟 Features
Efficient QC Processing: Subsampling and QC for WGS data.
Modular Design: All processes are modularized for ease of maintenance and customization.
Conda Integration: Each sub-workflow has a dedicated Conda environment.

## 📋 Requirements
Nextflow: Version 23.10.1 or higher
Sun Grid Engine: For job scheduling
Conda: For managing software dependencies

## 📂 Directory Structure

```
AESPA
├── apps
│   └── GenomeAnalysisTK-3.7
├── bin
│   ├── sqs_calc
│   ├── sqs_generate.py
│   ├── sqs_merge.py
│   └── stat_summary.py
├── conf
│   ├── bam_stat_calculation.gatk.yml
│   ├── bam_stat_calculation.picard.yml
│   ├── bam_stat_calculation.yml
│   ├── base.config
│   ├── iSAAC_pipeline.yml
│   ├── LIMS_API.config
│   ├── modules.config
│   ├── preprocessing.yml
│   ├── reference.json
│   ├── sge_conda.config
│   ├── sge_local.config
│   ├── sge_local_season2.config
│   ├── strelka_variant_call.yml
│   ├── summary_qc_stat.yml
│   └── test.config
├── Figure
│   └── flow_chart.png
├── modules
│   ├── API
│   ├── local
│   └── nf-core
├── subworkflow
│   └── local
│       ├── bam_stat_calculation/
│       ├── bwa_pipeline/
│       ├── demux_check/
│       ├── input_check/
│       ├── iSAAC_pipeline/
│       ├── make_deliverables/
│       ├── preprocessing/
│       ├── QC_CHECK/
│       ├── report_prepare/
│       └── strelka_variant_call/
└── workflow
    └── aespa.nf
```

## 🛠 Installation

```sh
conda install git
conda env create -f $(find . -name '*.yml')
```

## 🚀 Usage
### Running the Pipeline
To run the pipeline with Conda environments enabled:
```sh
nextflow run main.nf -profile sge_conda_env --json_file input.json
```

To run the pipeline with local environments:
```sh
nextflow run main.nf -profile sge_local_env --json_file input.json
```
### Running the pipeline with Wrapper
```
call_AESPA_pipeline.sh -s sample_sheet.csv -f forward_read -r reverse_read -o output_dir
```

### Wrapper Script

```sh
#!/bin/bash
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

```

## 🧬 Workflow Details
![Pipeline Workflow](Figure/flow_chart.png)

Submodules
Preprocessing (preprocessing.nf)
iSAAC Alignment (iSAAC_pipeline.nf)
BAM Statistics Calculation (bam_stat_calculation.nf)
Variant Calling (strelka_variant_call.nf)
QC Summary (summary_qc_stat.nf)

## Example for bam_stat_calculation.yml
```yaml
name: calc_bam_stat
channels:
  - defaults
  - conda-forge
  - bioconda
dependencies:
  - python=3.11.3
  - verifybamid2=2.0.1
  - bedtools
  - pip
  - pip:
      - scipy
      - pysam
```

## 📄 Attached Reference Genome
RefSeq version Human Genome (GRCh38;hg38) without scaffolds.

## ⚙️ Customization
Conda Integration: Enable Conda environments with conda.enabled=true.
Local Environment: Configure paths in conf/sge_local.config.
Change Reference: Modify the file paths on the reference json file in conf/reference.json

## 📊 Performance
Speed: 3-4 times faster than the traditional iSAAC pipeline.
Resource Usage: Approx. 1 hour runtime with a max memory usage of 40GB.
Accuracy: Moderate error (MSE 3-5) with accurate mappable mean depth, deduplication rate, and contaminated reads.
