#!/usr/bin/env nextflow

workflow calc_bams {
    take:
    bam_ch
    ref_ch

    main:
    calc_freemix_values(bam_ch, ref_ch)
    calc_genome_coverage(bam_ch)
    calc_DOC(bam_ch, ref_ch)
    calc_distance(bam_ch, calc_genome_coverage.out)
    calc_PE_insert_size(bam_ch)
    calc_samtools_flagstat(bam_ch)

    emit:
    flagstat_out_file = calc_samtools_flagstat.out
    picard_insertsize_file = calc_PE_insert_size.out
    gatk_doc_file = calc_DOC.out.sample_summary
    freemix_out_file = calc_freemix_values.out.vb2_out
    doc_distance_out_file = calc_distance.out
}

process calc_freemix_values {
    label "process_low"
    tag "calc freemix for ${sample_id}"
    conda "${baseDir}/workflow/bam_stat_calculation.yml"
    publishDir "${output_dir}/stat_outputs", mode: 'copy'

    input:
    tuple val(sample_id), path(out_bam), path(out_bai), path(output_dir)
    tuple path(ref), path(ref_fai), path(ref_dict)

    output:
    path "*.freemix.vb2.selfSM", emit: vb2_out
    path "*vb?.*"

    script:
    """
    verifybamid2_db_bed=\$(dirname \$(dirname \$(which verifybamid2)))/share/verifybamid2*/resource/1000g.phase3.100k.b38.vcf.gz.dat.bed
    verifybamid2_db_prefix=\${verifybamid2_db_bed%.bed}
    verifybamid2 \
    --SVDPrefix \${verifybamid2_db_prefix} \
    --BamFile ${out_bam} \
    --Reference ${ref} \
    --Output ${sample_id}.freemix.vb2 \
    --min-MQ 37 \
    --min-BQ 20 \
    --adjust-MQ 50 \
    --no-orphans \
    --NumPC 4 \
    --Epsilon 1e-11
    """
}

process calc_genome_coverage {
    label "process_single"
    publishDir "${output_dir}/stat_outputs", mode: 'copy'
    conda "${baseDir}/workflow/bam_stat_calculation.yml"

    input:
    tuple val(sample_id), path(out_bam), path(out_bai), path(output_dir)

    output:
    path "*.genomecov"

    script:
    """
    bedtools \\
        genomecov \\
        -ibam ${out_bam} \\
        > ${sample_id}.genomecov
    """
}

process calc_DOC {
    label "process_low"
    publishDir "${output_dir}/stat_outputs", mode: 'copy'
    tag "depth of coverage for ${sample_id}"

    input:
    tuple val(sample_id), path(out_bam), path(out_bai), path(output_dir)
    tuple path(ref), path(ref_fai), path(ref_dict)

    output:
    path "*.depthofcov.sample_summary", emit: sample_summary
    path "*.depthofcov*"

    script:
    """
    GATK_temp=\$(mktemp -d)
    java \
        -Xmx25g \
        -Djava.io.tmpdir=\$GATK_temp \
        -jar \$GATK3 \
        -T DepthOfCoverage \
        -R ${ref} \
        -I ${out_bam} \
        -o ${sample_id}.depthofcov \
        -ct 1 -ct 5 -ct 10 -ct 15 -ct 20 -ct 30 \
        -omitBaseOutput \
        --omitIntervalStatistics \
        --omitLocusTable \
        -nt 30
    sleep 1
    rm -fr \$GATK_temp
    """
}

process calc_distance {
    label "process_single"
    publishDir "${output_dir}/stat_outputs", mode: 'copy'
    tag "depth of coverage distance for ${sample_id}"
    conda "${baseDir}/workflow/bam_stat_calculation.yml"

    input:
    tuple val(sample_id), path(out_bam), path(out_bai), path(output_dir)
    path genome_coverage

    output:
    path "*.depthofcov.stat"
    
    script:
    """
    DOC_distance.py \\
        ${genome_coverage} \\
        > ${sample_id}.depthofcov.stat
    """
}

process calc_PE_insert_size {
    label "process_low"
    publishDir "${output_dir}/stat_outputs", mode: 'copy'
    tag "Picard insertsize calculation for ${sample_id}"
    conda "${baseDir}/workflow/bam_stat_calculation.picard.yml"

    input:
    tuple val(sample_id), path(out_bam), path(out_bai), path(output_dir)

    output:
    path "*.insert_size_metrics"

    script:
    """
    picard \\
        CollectInsertSizeMetrics \\
        H=insert_size_hist.pdf \\
        I=${out_bam} \\
        O=${sample_id}.insert_size_metrics \\
        VALIDATION_STRINGENCY=LENIENT
    """
}

process calc_samtools_flagstat {
    label "process_single"
    tag "samtools flagstats for ${sample_id}"
    publishDir "${output_dir}/stat_outputs", mode: 'copy'
    conda "${baseDir}/workflow/bam_stat_calculation.yml"

    input:
    tuple val(sample_id), path(out_bam), path(out_bai), path(output_dir)

    output:
    path "*.flagstat"

    script:
    """
    samtools_flagstat.py ${out_bam} > ${sample_id}.flagstat
    """
}
