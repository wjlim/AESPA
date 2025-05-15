process calc_DOC {
    label "process_low"
    tag "depth of coverage for ${meta.id}"
    conda (params.conda_env_path ? "${params.conda_env_path}/nf_gatk" : "${moduleDir}/environment.yml")

    input:
    tuple val(meta), path(inbam), path(inbai), path(ref), path(ref_fai), path(ref_dict)

    output:
    tuple val(meta), path( "*.depthofcov.sample_summary"), emit: sample_summary
    path "*.depthofcov*"

    script:
    """
    set -e
    java \
        -Xms1G \
        -Xmx${task.memory.toGiga()}G \
        -jar $GATK3 \
        -T DepthOfCoverage \
        -R ${ref} \
        -I ${inbam} \
        -o ${meta.id}.depthofcov \
        -ct 1 -ct 5 -ct 10 -ct 15 -ct 20 -ct 30 \
        -omitBaseOutput \
        --omitIntervalStatistics \
        --omitLocusTable \
        -nt 30
    touch ${meta.id}.depthofcov.sample_summary
    """
}
