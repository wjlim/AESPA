process BLAST_UNMAPPED_READS {
    label "process_low"
    tag "BLAST unmapped reads for ${meta.order}.${meta.sample}.${meta.fc_id}.L00${meta.lane}"
    conda NXF_OFFLINE == 'true' ?
        "${params.conda_env_path}/envs/blast_unmapped_env":
        "${baseDir}/conf/blast_unmapped_env.yml"

    input:
    tuple val(meta), path(out_bam), path(out_bai)

    output:
    tuple val(meta), path( "blast_top_10.txt"), emit: ch_blast_results

    script:
    def subsample_reads = 1000
    """
    set -e
    touch blast.txt
    samtools view -b -f 4 ${out_bam} |bedtools bamtofastq -i stdin -fq unmapped_R1.fastq
    seqtk sample -s 10 unmapped_R1.fastq ${subsample_reads} > unmapped_R1_${subsample_reads}.fastq
    seqtk seq -a unmapped_R1_${subsample_reads}.fastq > unmapped_R1.fa
    export BLASTDB=${params.blastn_db}
    blastn -num_threads 4 -db \$BLASTDB/nt -query unmapped_R1.fa -evalue 1.0E-3 -max_target_seqs 5 -outfmt '6 qseqid qstart qend qcovs qcovhsp qcovus sseqid stitle sstart send evalue bitscore nident pident mismatch gaps sstrand staxids sscinames' -out blast.txt
    for i in `cat blast.txt | awk {'print \$1'} | sort | uniq ` ; do
        cat blast.txt | grep \${i} | head -n 1 | cut -d\$'\t' -f19 | sort | uniq -c | sort -n -r 
    done | sort | uniq -c | sort -n -r >> blast_all_species.txt
    head -n 10 blast_all_species.txt >> blast_top_10.txt
    """
}