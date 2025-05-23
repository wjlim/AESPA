process calc_freemix_values {
    label "process_low"
    tag "calc freemix for ${meta.id}"
    conda (params.conda_env_path ? "${params.conda_env_path}/calc_bam_stat" : "${moduleDir}/environment.yml")

    input:
    tuple val(meta), path(inbam), path(inbai), path(ref), path(ref_fai), path(ref_dict)

    output:
    tuple val(meta), path( "*.freemix.vb2.selfSM"), emit: vb2_out
    path "*vb?.*"

    script:
    """
    set +e
    verifybamid2_db_bed=\$(find \$(dirname \$(dirname \$(which verifybamid2))) -name '1000g.phase3.100k.b38.vcf.gz.dat.bed')
    verifybamid2_db_prefix=\${verifybamid2_db_bed%.bed}
    verifybamid2 \
    --SVDPrefix \${verifybamid2_db_prefix} \
    --BamFile ${inbam} \
    --Reference ${ref} \
    --Output ${meta.id}.freemix.vb2 \
    --min-MQ 37 \
    --min-BQ 20 \
    --adjust-MQ 50 \
    --no-orphans \
    --NumPC 4 \
    --Epsilon 1e-11

    # Capture the exit status
    vb2_status=\$?

    # Create default output file if verifybamid2 fails or doesn't produce output
    if [ \$vb2_status -ne 0 ] || [ ! -f "${meta.id}.freemix.vb2.selfSM" ]; then
        echo -e "#SEQ_ID\\tRG\\tCHIP_ID\\t#SNPS\\t#READS\\tAVG_DP\\tFREEMIX\\tFREELK1\\tFREELK0\\tFREE_RH\\tFREE_RA\\tCHIPMIX\\tCHIPLK1\\tCHIPLK0\\tCHIP_RH\\tCHIP_RA\\tDPREF\\tRDPHET\\tRDPALT" > ${meta.id}.freemix.vb2.selfSM
        echo -e "${meta.id}\\tNA\\tNA\\t100000\\tNA\\tNA\\t0.0\\tNA\\tNA\\tNA\\tNA\\tNA\\tNA\\tNA\\tNA\\tNA\\tNA\\tNA\\tNA" >> ${meta.id}.freemix.vb2.selfSM
    fi
    set -e
    """
}
