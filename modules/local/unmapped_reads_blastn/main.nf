process BLAST_UNMAPPED_READS {
    label "process_low"
    tag "BLAST unmapped reads for ${meta.id}"
    conda params.conda_env_path? "${params.conda_env_path}/blastn":
        "${moduleDir}/environment.yml"

    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://community-cr-prod.seqera.io/docker/registry/v2/blobs/sha256/52/5222a42b366a0468a4c795f5057c2b8cfe39489548f8bd807e8ac0f80069bad5/data':
        'community.wave.seqera.io/library/blast:2.16.0--540f4b669b0a0ddd' }"

    input:
    tuple val(meta), path(out_bam), path(out_bai)

    output:
    tuple val(meta), path( "blast_top_10.txt"), emit: ch_blast_results

    script:
    def subsample_reads = 1000
    """
    # samtools view -b -f 4 ${out_bam} |bedtools bamtofastq -i stdin -fq unmapped_R1.fastq
    # seqtk sample -s 10 unmapped_R1.fastq ${subsample_reads} > unmapped_R1_${subsample_reads}.fastq
    # seqtk seq -a unmapped_R1_${subsample_reads}.fastq > unmapped_R1.fa
    # export BLASTDB=${params.blastn_db}
    # blastn -num_threads 4 -db \$BLASTDB/nt -query unmapped_R1.fa -evalue 1.0E-3 -max_target_seqs 5 -outfmt '6 qseqid qstart qend qcovs qcovhsp qcovus sseqid stitle sstart send evalue bitscore nident pident mismatch gaps sstrand staxids sscinames' -out blast.txt
    # for i in `cat blast.txt | awk {'print \$1'} | sort | uniq ` ; do
    #     cat blast.txt | grep \${i} | head -n 1 | cut -d\$'\t' -f19 | sort | uniq -c | sort -n -r
    # done | sort | uniq -c | sort -n -r >> blast_all_species.txt
    # head -n 10 blast_all_species.txt >> blast_top_10.txt
    echo "BLAST_UNMAPPED_READS"
    """
}
