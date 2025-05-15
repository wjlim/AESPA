process calc_genome_coverage {
    label "process_low"
    tag "Get genome cov for ${meta.id}"
    conda (params.conda_env_path ? "${params.conda_env_path}/calc_bam_stat" : "${moduleDir}/environment.yml")

    input:
    tuple val(meta), path(out_bam), path(out_bai)

    output:
    tuple val(meta), path("*.genomecov"), emit:ch_genomecov
    tuple val(meta), path("*.sex"), emit:ch_sex

    script:
    """
    set -e
    touch ${meta.id}.genomecov
    touch ${meta.id}.sex
    bedtools \\
        genomecov \\
        -ibam ${out_bam} \\
        > ${meta.id}.genomecov

    covX=`grep "^chrX"  ${meta.id}.genomecov | awk '{ x = \$2 * \$3 ; sum += x }; END { print sum }'`
    covY=`grep "^chrY"  ${meta.id}.genomecov | awk '{ x = \$2 * \$3 ; sum += x }; END { print sum }'`

    ratio=`echo "\$covX/\$covY" | bc -l`
    ratio_n=\$(printf "%.2g\\n" "\$ratio")

    if [[ `echo "\$ratio < 6" | bc` -eq 1 ]]
    then
        echo "CovX,CovY,Ratio,sex" > ${meta.id}.sex
        echo "\$covX,\$covY,\$ratio_n,M" >> ${meta.id}.sex

    else
        echo "CovX,CovY,Ratio,sex" > ${meta.id}.sex
        echo "\$covX,\$covY,\$ratio_n,F" >> ${meta.id}.sex
    fi

    """
}
