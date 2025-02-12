process raw_data_search {
    label 'process_single'
    tag "Samplesheet validation"
    conda NXF_OFFLINE == 'true' ?
        "${params.conda_env_path}/envs/RapidQC_preprocessing":
        "${baseDir}/conf/preprocessing.yml"

    input:
    path sample_sheet
    path run_dir

    output:
    path "samplesheet.valid.csv", emit: ch_samplesheet_path

    script:
    """
    #!/usr/bin/env python
    import csv
    import os
    from glob import glob
    sample_sheet_path = "${sample_sheet}"
    dem_dir_path = "${run_dir}"

    with open(sample_sheet_path, 'r') as fin, open("samplesheet.valid.csv", 'w', newline='') as fout:
        reader = csv.DictReader(fin)
        fieldnames = reader.fieldnames + ['fastq_1', 'fastq_2']
        writer = csv.DictWriter(fout, fieldnames=fieldnames)
        
        writer.writeheader()
        for row in reader:
            sample_id = row['SampleID']
            order = row['Project']
            lane = row['Lane']
            
            fastq_1_pattern = f"{dem_dir_path}/{order}/{order}_{sample_id}/{sample_id}_S*_L00{lane}_*1_001.fastq.gz"
            fastq_2_pattern = f"{dem_dir_path}/{order}/{order}_{sample_id}/{sample_id}_S*_L00{lane}_*2_001.fastq.gz"
            fastq_1_file = glob(fastq_1_pattern)
            fastq_2_file = glob(fastq_2_pattern)
            
            if len(fastq_1_file) == 1 and len(fastq_2_file) == 1:
                row['fastq_1'] = os.popen(f'readlink -f {fastq_1_file[0]}').read().strip()
                row['fastq_2'] = os.popen(f'readlink -f {fastq_2_file[0]}').read().strip()
                writer.writerow(row)
            else:
                print(f"Skipping invalid raw data paths: {fastq_1_pattern}, {fastq_2_pattern}")
    """
}