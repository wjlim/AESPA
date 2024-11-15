process calc_freemix_values {
    label "process_low"
    tag "calc freemix for ${meta.order}.${meta.sample}.${meta.fc_id}.L00${meta.lane}"
    conda NXF_OFFLINE == 'true' ?
        "/mmfs1/lustre2/BI_Analysis/wjlim/anaconda3/envs/calc_bam_stat":
        "${baseDir}/conf/bam_stat_calculation.yml"

    input:
    tuple val(meta), path(out_bam), path(out_bai), path(ref), path(ref_fai), path(ref_dict)

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
    --BamFile ${out_bam} \
    --Reference ${ref} \
    --Output ${meta.id}.freemix.vb2 \
    --min-MQ 37 \
    --min-BQ 20 \
    --adjust-MQ 50 \
    --no-orphans \
    --NumPC 4 \
    --Epsilon 1e-11

    #if [ \$? -ne 0 ];then
    #    echo -e "#SEQ_ID\\tRG\\tCHIP_ID\\t#SNPS\\t#READS\\tAVG_DP\\tFREEMIX\\tFREELK1\\tFREELK0\\tFREE_RH\\tFREE_RA\\tCHIPMIX\\tCHIPLK1\\tCHIPLK0\\tCHIP_RH\\tCHIP_RA\\tDPREF\\tRDPHET\\tRDPALT" > ${meta.id}.freemix.vb2.selfSM
    #    echo -e "${meta.id}\\tNA\\tNA\\t100000\\tNA\\tNA\\t0.0\\tNA\\tNA\\tNA\\tNA\\tNA\\tNA\\tNA\\tNA\\tNA\\tNA\\tNA\\tNA" >> ${meta.id}.freemix.vb2.selfSM
    #fi
    set -e
    """
}