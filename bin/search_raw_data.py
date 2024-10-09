import csv
import os
from glob import glob
dem_dir_path = sys.argv[1]
sample_sheet_path = sys.argv[2]

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
        
        if len(fastq_1_file) != 1 or len(fastq_2_file) != 1:
            if len(fastq_1_file) != 1 and len(fastq_2_file) != 1:
                print(f"Error: FastQ files not found for {fastq_1_pattern}, {fastq_2_pattern}")
            elif len(fastq_1_file) != 1:
                print(f"Error: FastQ files not found for {fastq_1_pattern}")
            else:
                print(f"Error: FastQ files not found for {fastq_2_pattern}")
            sys.exit(1)
        else:
            row['fastq_1'] = os.path.abspath(fastq_1_file[0])
            row['fastq_2'] = os.path.abspath(fastq_2_file[0])
            writer.writerow(row)