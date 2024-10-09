process calc_DOC {
    label "process_low"
    tag "depth of coverage for ${meta.id}"
    conda NXF_OFFLINE == 'true' ?
        "${params.conda_env_path}/envs/nf_gatk":
        "${baseDir}/conf/bam_stat_calculation.gatk.yml"

    input:
    tuple val(meta), path(out_bam), path(out_bai), path(ref), path(ref_fai), path(ref_dict)

    output:
    tuple val(meta), path( "*.depthofcov.sample_summary"), emit: sample_summary
    path "*.depthofcov*"

    script:
    """
    java \
        -Xmx25g \
        -jar $GATK3 \
        -T DepthOfCoverage \
        -R ${ref} \
        -I ${out_bam} \
        -o ${meta.id}.depthofcov \
        -ct 1 -ct 5 -ct 10 -ct 15 -ct 20 -ct 30 \
        -omitBaseOutput \
        --omitIntervalStatistics \
        --omitLocusTable \
        -nt 30
    """
}