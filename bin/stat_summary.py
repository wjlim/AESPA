#!/usr/bin/env python3
import pandas as pd
import configparser
import json
import re
import argparse

def sqs_parser(file_path):
    data = []
    with open(file_path, 'r') as file:
        lines = file.readlines()
    for i in range(0, len(lines), 10):
        first_line = lines[i].split()
        sample_id = first_line[0]
        total_bases = int(first_line[1])
        total_num_of_reads = int(first_line[2])
        n_percent = float(first_line[3])
        gc_percent = float(first_line[4])
        q20_percent = float(first_line[5])
        q30_percent = float(first_line[6])
        avg_read_size = float(lines[i+9].split(': ')[1])
        sample_data = {
            'sample_id': sample_id,
            'total_bases': total_bases,
            'total_num_of_reads': total_num_of_reads,
            'n_percent': n_percent,
            'gc_percent': gc_percent,
            'q20_percent': q20_percent,
            'q30_percent': q30_percent,
            'avg_read_size': avg_read_size
        }
        data.append(sample_data)
    return pd.DataFrame(data)

def process_vcf(vcf_file):
    nSNPs = 0
    nINSs = 0
    nDELs = 0

    with open(vcf_file, 'r') as file:
        for line in file:
            if line.startswith('#'):
                continue

            columns = line.strip().split('\t')
            ref = columns[3]
            alt = columns[4].split(',')

            for allele in alt:
                if len(ref) == 1 and len(allele) == 1:
                    nSNPs += 1
                elif len(ref) < len(allele):
                    nINSs += 1
                elif len(ref) > len(allele):
                    nDELs += 1
    return nSNPs, nINSs, nDELs

def check_DOC_conditions(doc_file):
    check = 0
    mode = iqr = distance = None

    # Open the document file
    with open(doc_file, 'r') as file:
        for line in file:
            parts = line.strip().split('\t')
            if len(parts) < 2:
                continue
            key, value = parts[0], parts[1]
            if key == "Mode":
                mode = float(value)
                if -0.3 <= mode <= 0.1:
                    check += 1
            elif key == "IQR 75%-25%":
                iqr = float(value)
                if iqr <= 1.0:
                    check += 1
            elif key == "Distance":
                distance = float(value)
                if distance <= 1.0:
                    check += 1
        if check == 3:
            DOC = 'PASS'
        else:
            DOC = 'FAIL'
    return DOC, mode, iqr, distance

def main():
    parser = argparse.ArgumentParser(description='Process bioinformatics data.')
    parser.add_argument('-c','--config_stat_file', required=True, help='Path to the .txt config file listing stat files')
    parser.add_argument('-l','--lib_group', required=True, help='Library group identifier')
    parser.add_argument('-j', '--json_file', required=True, help='Path to the JSON configuration file')
    parser.add_argument('-o', '--output', help='file name of output: default = stdout')
    args = parser.parse_args()

    # Load configurations
    config = configparser.ConfigParser()
    config.read(args.config_stat_file)
    lib_group = args.lib_group
    output_file = args.output

    # Load JSON configuration
    with open(args.json_file, 'r') as file:
        sample_config = json.load(file)

    sqs_file = config.get('stat_files', 'sqs_file')
    kmer_out = config.get('stat_files', 'kmer_out')
    flagstat_out = config.get('stat_files', 'flagstat_out')
    picard_insertsize = config.get('stat_files', 'picard_insertsize')
    GATK_DOC = config.get('stat_files', 'GATK_DOC')
    freemix_out = config.get('stat_files', 'freemix_out')
    out_vcf = config.get('stat_files', 'out_vcf')
    DOC_distance_out = config.get('stat_files', 'DOC_distance_out')

    sqs_df = sqs_parser(sqs_file)
    kmer_df = pd.read_csv(kmer_out)
    flagstat_df = pd.read_table(flagstat_out, header = None, index_col = 0).T
    picard_is_df = pd.read_table(picard_insertsize, skip_blank_lines=True, comment = '#', header = 0, nrows = 1)
    GATK_DOC_df = pd.read_table(GATK_DOC, header = 0, nrows = 1)
    freemix_df = pd.read_table(freemix_out, header = 0)
    nSNPs, nINSs, nDELs = process_vcf(out_vcf)
    DOC_check, mode, iqr, distance = check_DOC_conditions(DOC_distance_out)

    order_num = sample_config['order_num']
    sample_id = sqs_df['sample_id'][0]
    total_bases = sqs_df['total_bases'][0]
    total_reads = sqs_df['total_num_of_reads'][0]
    avg_read_length = sqs_df['avg_read_size'][0] - 1
    genome_size = 2934 * 1000 * 1000
    throughput_mean_depth = total_bases/genome_size
    dedup_rate = float(kmer_df['Deduplicated Rate'][0].replace('%','')) / 100
    dedupped_reads = int(total_reads * dedup_rate)
    sub_total_reads = flagstat_df['total_read'][1]
    sub_mapped_reads = flagstat_df['all_mappable_reads'][1]
    sub_dedupped_mapped_reads = flagstat_df['mappable_reads'][1]
    mapping_rate = sub_mapped_reads / sub_total_reads
    dedupped_mapping_rate = sub_dedupped_mapped_reads / sub_total_reads
    dedupped_mapped_reads = dedupped_reads * mapping_rate
    mapped_yield = int(dedupped_reads * avg_read_length * dedupped_mapping_rate)
    mapped_mean_depth = mapped_yield / genome_size
    cov_1x = GATK_DOC_df['%_bases_above_1'][0]
    cov_5x = GATK_DOC_df['%_bases_above_5'][0]
    cov_10x = GATK_DOC_df['%_bases_above_10'][0]
    cov_15x = GATK_DOC_df['%_bases_above_15'][0]
    cov_20x = GATK_DOC_df['%_bases_above_20'][0]
    cov_30x = GATK_DOC_df['%_bases_above_30'][0]
    insert_median_length = picard_is_df['MEDIAN_INSERT_SIZE'][0]
    insert_std = picard_is_df['MEDIAN_ABSOLUTE_DEVIATION'][0]
    syn_mut = non_sym_mut = splicing = stop_gain = stop_los = fram_shift \
    = dbSNP138 = dbSNP154 = CNV_gain = CNV_loss = DUP = INS = DEL = INV = TRANS = hethom = TsTv = 0
    freemix = freemix_df['FREEMIX'][0]

    outfmt = \
f'''Order no.\t{order_num}
Sample ID\t{sample_id}
Total reads\t{total_reads}
Read length (bp)\t{avg_read_length}
Total yield (Mbp)\t{total_bases/(1000*1000):.0f}
Reference size (Mbp)\t{genome_size/(1000*1000)}
Throughput mean depth (X)\t{throughput_mean_depth:.2f}
De-duplicated reads\t{dedupped_reads:.2f}
De-duplicated reads % (out of total reads)\t{dedup_rate * 100}
Mappable reads (reads mapped to human genome)\t{dedupped_mapped_reads:.0f}
Mappable reads % (out of de-duplicated reads)\t{dedupped_mapping_rate*100:.2f}
Mappable yield (Mbp)\t{mapped_yield}
Mappable mean depth (X)\t{mapped_mean_depth}
% >= 1X coverage\t{cov_1x}
% >= 5X coverage\t{cov_5x}
% >= 10X coverage\t{cov_10x}
% >= 15X coverage\t{cov_15x}
% >= 20X coverage\t{cov_20x}
% >= 30X coverage\t{cov_30x}
Fragment length median\t{insert_median_length}
Standard deviation\t{insert_std}
SNPs\t{nSNPs}
Small insertions\t{nINSs}
Small deletions\t{nDELs}
Synonymous coding variants\t{syn_mut}
Non-synonymous coding variants\t{non_sym_mut}
splicing variants\t{splicing}
stop gained\t{stop_gain}
stop lost\t{stop_los}
frame shift\t{fram_shift}
% found in dbSNP138\t{dbSNP138}
% found in dbSNP154\t{dbSNP154}
Copy number gains\t{CNV_gain}
Copy number losses\t{CNV_loss}
Duplications\t{DUP}
Insertions\t{INS}
Deletions\t{DEL}
Inversions\t{INV}
Translocations\t{TRANS}
het/hom ratio\t{hethom:.2f}
Ts/Tv ratio\t{TsTv:.2f}
DOC\t{DOC_check}
Mode\t{mode}
IQR\t{iqr}
Distance\t{distance}
ASN_Freemix\t{freemix}
EUR_Freemix\t{freemix}
Lib_Group\t{lib_group}
'''

    if output_file:
        with open(output_file, 'w') as f:
            f.write(outfmt)
    else:
        print(outfmt)
if __name__== '__main__':
    main()
