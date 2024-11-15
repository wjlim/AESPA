process passed_file_check{
    label 'process_single'
    tag "Check all the confirm.txt for ${meta.sample}"
    conda NXF_OFFLINE == 'true' ?
        "${params.conda_env_path}/envs/RapidQC_preprocessing":
        "${baseDir}/conf/preprocessing.yml"
    
    input:
    tuple val(meta), path(confirm_csv)
    
    output:
    tuple val(meta), path('passed_forward_reads.txt'), path('passed_reverse_reads.txt'), emit:ch_passed_files

    script:
    def project_path = params.project_path
    def run_dir = params.prefix

    """
#!/usr/bin/env python
import pandas as pd
from glob import glob
import os

passed_df = pd.read_csv("${confirm_csv}")
with open('passed_forward_reads.txt','w') as f1, open('passed_reverse_reads.txt','w') as f2:
    for i in range(passed_df.shape[0]):
        order = passed_df.iloc[i,:]['Project']
        sample = passed_df.iloc[i,:]['SampleID']
        run_dir = passed_df.iloc[i,:]['AnalysisPath']
        lane = passed_df.iloc[i,:]['Lane']
        fastq_1 = glob(f"${project_path}/{order}/{run_dir}/{sample}/LaneFastq/*{sample}*{lane}*1.fastq.gz")
        fastq_2 = glob(f"${project_path}/{order}/{run_dir}/{sample}/LaneFastq/*{sample}*{lane}*2.fastq.gz")
        if len(fastq_1) == 1 and len(fastq_2) == 1:
            f1.write(f"{fastq_1[0]}\\n")
            f2.write(f"{fastq_2[0]}\\n")
            os.symlink(fastq_1[0], os.path.basename(fastq_1[0]))
            os.symlink(fastq_2[0], os.path.basename(fastq_2[0]))
    """
}