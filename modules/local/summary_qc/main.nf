process summary_qc {
    label "process_single"
    tag "generate result summary qc file for ${meta.id}"
    conda params.conda_env_path? "${params.conda_env_path}/preprocessing":"${moduleDir}/environment.yml"

    input:
    tuple val(meta),
          path(sqs_file),
          path(kmer_out),
          path(flagstat_out),
          path(picard_insertsize),
          path(GATK_DOC),
          path(freemix_out),
          path(doc_distance_out_file),
          path(sex_file),
          path(out_vcf)

    output:
    tuple val(meta), path("*.QC.summary"), emit: qc_report
    tuple val(meta), path("*.json"), emit: qc_json

    script:
    """
#!/usr/bin/env python3
import pandas as pd
import json

def sqs_parser(file_path):
    for i, row in enumerate(map(lambda x:x.strip().split('\\t'), open(file_path))):
        if i == 0:
            sample_id = row[0]
            total_bases = int(row[1])
            total_num_of_reads = int(row[2])
            n_percent = float(row[3])
            gc_percent = float(row[4])
            q30_percent = float(row[5])
            q20_percent = float(row[6])
        if i == 9:
            avg_read_size = float(row[0].split(':')[1].strip())
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
    return pd.DataFrame([sample_data])

def process_vcf(vcf_file):
    nSNPs = 0
    nINSs = 0
    nDELs = 0

    with open(vcf_file, 'r') as file:
        for line in file:
            if line.startswith('#'):
                continue
            try:
                columns = line.strip().split('\\t')
                ref = columns[3]
                alt = columns[4].split(',')

                for allele in alt:
                    if len(ref) == 1 and len(allele) == 1:
                        nSNPs += 1
                    elif len(ref) < len(allele):
                        nINSs += 1
                    elif len(ref) > len(allele):
                        nDELs += 1
            except Exception as e:
                print(f"Error processing line: {line.strip()}")
    return nSNPs, nINSs, nDELs

def check_DOC_conditions(doc_file):
    check = 0
    mode = iqr = distance = None
    try:
        with open(doc_file, 'r') as file:
            for line in file:
                parts = line.strip().split('\\t')
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
    except:
        DOC = 'FAIL'
    return DOC, mode, iqr, distance

def main():
    # Initialize variables
    syn_mut = non_sym_mut = splicing = stop_gain = stop_los = fram_shift = dbSNP138 = dbSNP154 = CNV_gain = CNV_loss = DUP = INS = DEL = INV = TRANS = hethom = TsTv = 0

    # Read input files
    sqs_df = sqs_parser("${sqs_file}")
    try:
        kmer_df = pd.read_csv("${kmer_out}")
    except:
        kmer_df = pd.DataFrame(columns=['Deduplicated Rate'])

    flagstat_df = pd.read_table("${flagstat_out}", header=None, index_col=0).T

    try:
        picard_is_df = pd.read_table("${picard_insertsize}", skip_blank_lines=True, comment='#', header=0, nrows=1)
        insert_median_length = picard_is_df['MEDIAN_INSERT_SIZE'][0]
        insert_std = picard_is_df['MEDIAN_ABSOLUTE_DEVIATION'][0]
    except:
        insert_median_length = 0
        insert_std = 0

    try:
        GATK_DOC_df = pd.read_table("${GATK_DOC}", header=0, nrows=1)
        mean_depth = GATK_DOC_df['mean'][0]
        cov_1x = GATK_DOC_df['%_bases_above_1'][0]
        cov_5x = GATK_DOC_df['%_bases_above_5'][0]
        cov_10x = GATK_DOC_df['%_bases_above_10'][0]
        cov_15x = GATK_DOC_df['%_bases_above_15'][0]
        cov_20x = GATK_DOC_df['%_bases_above_20'][0]
        cov_30x = GATK_DOC_df['%_bases_above_30'][0]
    except:
        mean_depth = 0
        cov_1x = 0
        cov_5x = 0
        cov_10x = 0
        cov_15x = 0
        cov_20x = 0
        cov_30x = 0

    freemix_df = pd.read_table("${freemix_out}", header=0)
    nSNPs, nINSs, nDELs = process_vcf("${out_vcf}")
    DOC_check, mode, iqr, distance = check_DOC_conditions("${doc_distance_out_file}")

    # Read sex file
    try:
        sex_df = pd.read_csv("${sex_file}", header=0)
        if 'sex' in sex_df.columns:
            sex = sex_df['sex'].iloc[0]
        else:
            sex = ''
    except:
        sex = ''

    # Calculate metrics
    order_num = "${meta.order}"
    sample_id = "${meta.id}"
    total_bases = sqs_df['total_bases'][0]
    total_reads = sqs_df['total_num_of_reads'][0]
    avg_read_length = sqs_df['avg_read_size'][0] - 1
    genome_size = 2934 * 1000 * 1000
    throughput_mean_depth = total_bases/genome_size

    if "${meta.subsampling}" == "false":
        duplicates = int(flagstat_df['all_duplicates'][1])
        dedupped_reads = total_reads - duplicates
        dedup_rate = dedupped_reads / float(total_reads)
    else:
        try:
            dedup_rate = ((float(kmer_df['Deduplicated Rate'][0].replace('%','')) - 16.47) * 1.25 ) / 100
            dedupped_reads = int(total_reads * dedup_rate)
        except:
            dedup_rate = 0
            dedupped_reads = 0

    if dedup_rate >= 100:
        dedup_rate = 99.99

    sub_total_reads = flagstat_df['total_read'][1]
    sub_mapped_reads = flagstat_df['mappable_reads'][1]
    sub_duplicates = int(flagstat_df['all_duplicates'][1])
    mapping_rate = sub_mapped_reads / sub_total_reads
    dedupped_mapping_rate = sub_mapped_reads / (sub_total_reads - sub_duplicates)
    dedupped_mapped_reads = dedupped_reads * mapping_rate
    mapped_yield = int(dedupped_reads * avg_read_length * dedupped_mapping_rate)

    if "${meta.subsampling}" == "false" and mean_depth != 0:
        mapped_mean_depth = mean_depth
    else:
        mapped_mean_depth = mapped_yield / genome_size

    # Generate QC summary file
    outfmt = f'''Order no.\t{order_num}
Sample ID\t{sample_id}
Total reads\t{total_reads:.0f}
Read length (bp)\t{avg_read_length:.0f}
Total yield (Mbp)\t{total_bases/(1000*1000):.0f}
Reference size (Mbp)\t{genome_size/(1000*1000):.0f}
Throughput mean depth (X)\t{throughput_mean_depth:.2f}
De-duplicated reads\t{dedupped_reads/(1000*1000):.0f}
De-duplicated reads % (out of total reads)\t{dedup_rate * 100:.2f}
Mappable reads (reads mapped to human genome)\t{dedupped_mapped_reads:.0f}
Mappable reads % (out of de-duplicated reads)\t{dedupped_mapping_rate * 100:.2f}
Mappable yield (Mbp)\t{mapped_yield/(1000*1000):.0f}
Mappable mean depth (X)\t{mapped_mean_depth:.2f}
% >= 1X coverage\t{cov_1x:.2f}
% >= 5X coverage\t{cov_5x:.2f}
% >= 10X coverage\t{cov_10x:.2f}
% >= 15X coverage\t{cov_15x:.2f}
% >= 20X coverage\t{cov_20x:.2f}
% >= 30X coverage\t{cov_30x:.2f}
Fragment length median\t{insert_median_length:.0f}
Standard deviation\t{insert_std:.0f}
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
Mode\t{mode:.2f}
IQR\t{iqr:.1f}
Distance\t{distance:.4f}
ASN_Freemix\t{float(freemix_df['FREEMIX'][0]):.4e}
EUR_Freemix\t{float(freemix_df['FREEMIX'][0]):.4e}
Lib_Group\t'NULL'
Sex\t{sex}
'''

    # Write QC summary file
    with open("${meta.id}.QC.summary", 'w') as f:
        f.write(outfmt)
    # Set QC method
    if "${meta.subsampling}" == "false":
        qc_method = "TOTAL"
    else:
        qc_method = "AESPA"
    if float(dedup_rate) <= ${params.deduplicate_rate_limit} or float(dedupped_mapping_rate) <= ${params.mapping_rate_limit} or float(freemix_df['FREEMIX'][0]) >= ${params.freemix_limit}:
        qc_method = f"{qc_method}:F"

    # Prepare API request payload
    payload = {
        "uniqLibNo": "${meta.key}",
        "resultPath": "${meta.id}.QC.summary",
        "xxTread": f"{total_reads:.0f}",
        "xxRlength": f"{avg_read_length:.0f}",
        "xxYie": f"{total_bases/(1000*1000):.0f}",
        "xxRsize": f"{genome_size/(1000*1000):.0f}",
        "xxTmeandepth": f"{throughput_mean_depth:.2f}",
        "xxDupread": f"{dedupped_reads/(1000*1000):.0f}",
        "xxDupread2": f"{dedup_rate * 100:.2f}",
        "xxMapread": f"{dedupped_mapped_reads:.0f}",
        "xxMapread2": f"{dedupped_mapping_rate * 100:.2f}",
        "xxMapyield": f"{mapped_yield/(1000*1000):.0f}",
        "xxMapmeandepth": f"{mapped_mean_depth:.2f}",
        "xx1xcov": f"{cov_1x:.2f}",
        "xx5xcov": f"{cov_5x:.2f}",
        "xx10xcov": f"{cov_10x:.2f}",
        "xx15xcov": f"{cov_15x:.2f}",
        "xx20xcov": f"{cov_20x:.2f}",
        "xx30xcov": f"{cov_30x:.2f}",
        "xxSnps": str(nSNPs),
        "xxSmallins": str(nINSs),
        "xxSmalldel": str(nDELs),
        "xxScodvar": str(syn_mut),
        "xxNscodvar": str(non_sym_mut),
        "xxCopynumgan": str(CNV_gain),
        "xxCopynumloss": str(CNV_loss),
        "xxDuplication": str(DUP),
        "xxInsert": str(INS),
        "xxDel": str(DEL),
        "xxInver": str(INV),
        "xxTrans": str(TRANS),
        "xxSplicing": str(splicing),
        "xxStgain": str(stop_gain),
        "xxStlost": str(stop_los),
        "xxShift": str(fram_shift),
        "xxSnp138": str(dbSNP138),
        "xxSnp142": "0",
        "xxHethom": f"{hethom:.2f}",
        "xxTstv": f"{TsTv:.2f}",
        "xxDoc": DOC_check,
        "xxMode": f"{mode:.2f}",
        "xxIqr": f"{iqr:.1f}",
        "xxDistance": f"{distance:.4f}",
        "xxFreemixAsn": f"{float(freemix_df['FREEMIX'][0]):.4e}",
        "xxFreemixEur": f"{float(freemix_df['FREEMIX'][0]):.4e}",
        "qcMethod": qc_method,
        "xxSex": sex
    }

    # Write JSON file
    with open("${meta.id}_input.json", 'w') as f:
        json.dump([payload], f, indent = 4)

if __name__ == '__main__':
    main()
    """
}
