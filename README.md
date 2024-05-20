# AESPA: Accurate and Efficient Sub-sampling Pipeline for WGS analysis

## Overview
This pipeline is designed to perform quality control (QC) for whole genome sequencing (WGS) data by conducting 3x subsampling.
![flowchart](./Figure/flow_chart.png)
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

```arduino
wgs_qc
├── apps
│   └── GenomeAnalysisTK-3.7
├── bin
│   ├── batch.sh
│   ├── DOC_distance.py
│   ├── extract_variants
│   ├── samtools_flagstat.py
│   ├── sqs_generate.py
│   ├── stat_summary.py
│   ├── subsampler.sh
│   ├── subsampling.py
│   └── summary_stat.py
├── conf
│   ├── reference.json
│   ├── sge_conda.config
│   └── sge_local.config
├── input.json
├── main.nf
├── nextflow.config
├── run.nf_test.sh
├── src
│   ├── genome.dict
│   ├── genome.fa
│   ├── genome.fa.amb
│   ├── genome.fa.ann
│   ├── genome.fa.bwt
│   ├── genome.fa.fai
│   ├── genome.fa.pac
│   ├── genome.fa.sa
│   ├── genome.gff
│   ├── genome.gtf
│   └── sorted-reference.xml
└── workflow
    ├── bam_stat_calculation.nf
    ├── bam_stat_calculation.picard.yml
    ├── bam_stat_calculation.yml
    ├── iSAAC_pipeline.nf
    ├── iSAAC_pipeline.yml
    ├── preprocessing.nf
    ├── preprocessing.yml
    ├── strelka_variant_call.nf
    ├── strelka_variant_call.yml
    ├── summary_qc_stat.nf
    └── summary_qc_stat.yml
```

## 🛠 Installation

```sh
cd workflow/
conda env create -f workflow/preprocessing.yml
conda env create -f workflow/iSAAC_pipeline.yml
conda env create -f workflow/bam_stat_calculation.yml
conda env create -f workflow/strelka_variant_call.yml
conda env create -f workflow/summary_qc_stat.yml
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

### Example input.json
```json
{
    "raw_forward_input": "/your/input_R1.fastq.gz",
    "raw_reverse_input": "/your/input_R2.fastq.gz",
    "sample_sheet": "/path/your/SampleSheet.csv",
    "sample_id": "test",
    "result_dir": "/path/your/output"
}
```

### Example Script

```sh
#!/bin/bash
outdir=test
work=$outdir/work
json_file=input.json
nf_temp=$outdir/temp
export NXF_WORK=$work
export NXF_TEMP=$nf_temp
export NXF_OFFLINE=true # if it is not connected to internet.

mkdir -p $outdir
mkdir -p $work
mkdir -p $nf_temp

nextflow run main.nf \
    -profile sge_conda_env \
    --json_file $json_file \
    -with-report "$outdir/reports/nf_out.report.html" \
    -with-dag "$outdir/reports/flowchart.png" \
    -with-timeline "$outdir/reports/nf_out.timeline.report.html" \
    --log "$outdir/nxf.log" \
    -resume \
    -with-trace "$outdir/reports/trace.txt" \
    &> $outdir/run.log.txt
```

## 🧬 Workflow Details
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
