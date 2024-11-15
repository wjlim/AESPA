process summary_qc {
    label "process_single"
    tag "generate result summary qc file for ${meta.order}.${meta.sample}.${meta.fc_id}.L00${meta.lane}"
    conda NXF_OFFLINE == 'true' ?
        "${params.conda_env_path}/envs/RapidQC_preprocessing":
        "${baseDir}/conf/preprocessing.yml"

    input:
    tuple val(meta), 
          path(out_vcf), 
          path(sqs_file), 
          path(kmer_out), 
          path(flagstat_out), 
          path(picard_insertsize), 
          path(GATK_DOC), 
          path(freemix_out), 
          path(doc_distance_out_file),
          path(sex_file)
    output:
    tuple val(meta), path("*.QC.summary"), emit: qc_report

    script:
    """
    #!/usr/bin/env python3
    import pandas as pd
    import argparse

    def sqs_parser(file_path):
        for i, row in enumerate(map(lambda x:x.strip().split('\t'), open(file_path))):
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
        sqs_df = sqs_parser("${sqs_file}")
        kmer_df = pd.read_csv("${kmer_out}")
        flagstat_df = pd.read_table("${flagstat_out}", header=None, index_col=0).T
        picard_is_df = pd.read_table("${picard_insertsize}", skip_blank_lines=True, comment='#', header=0, nrows=1)
        GATK_DOC_df = pd.read_table("${GATK_DOC}", header=0, nrows=1)
        freemix_df = pd.read_table("${freemix_out}", header=0)
        nSNPs, nINSs, nDELs = process_vcf("${out_vcf}")
        DOC_check, mode, iqr, distance = check_DOC_conditions("${doc_distance_out_file}")
        sex_df = pd.read_csv("${sex_file}", header = 0)

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
            dedup_rate = ((float(kmer_df['Deduplicated Rate'][0].replace('%','')) - 16.47) * 1.25 ) / 100
            dedupped_reads = int(total_reads * dedup_rate)

        sub_total_reads = flagstat_df['total_read'][1]
        sub_mapped_reads = flagstat_df['all_mappable_reads'][1]
        sub_duplicates = int(flagstat_df['all_duplicates'][1])
        mapping_rate = sub_mapped_reads / sub_total_reads
        dedupped_mapping_rate = sub_mapped_reads / (sub_total_reads - sub_duplicates)
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
        syn_mut = non_sym_mut = splicing = stop_gain = stop_los = fram_shift = dbSNP138 = dbSNP154 = CNV_gain = CNV_loss = DUP = INS = DEL = INV = TRANS = hethom = TsTv = 0
        freemix = freemix_df['FREEMIX'][0]
        sex = sex_df['sex'][0]
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
    ASN_Freemix\t{freemix:.4e}
    EUR_Freemix\t{freemix:.4e}
    Lib_Group\t${meta.lib_group}
    Sex\t{sex}
    '''

        with open("${meta.order}.${meta.sample}.${meta.fc_id}.${meta.lane}.QC.summary", 'w') as f:
            f.write(outfmt)

    if __name__ == '__main__':
        main()
    """
}