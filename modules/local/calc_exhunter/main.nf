process calc_exhunter {
    tag "calculate exhunter for ${meta.id}"
    conda params.conda_env_path? "${params.conda_env_path}/faster": "${moduleDir}/environment.yml"
    input:
    tuple val(meta), path(inbam), path(inbai), path(ref), path(ref_fai), path(ref_dict)

    output:
    tuple val(meta), path("*.json"), emit: ch_exhunter_json
    tuple val(meta), path("*.bam"), emit: ch_exhunter_bam
    tuple val(meta), path("*.vcf"), emit: ch_exhunter_vcf

    script:
    def test_variant_catalog = "${baseDir}/src/BRCA1.variant_catalogue.example.json"
    """
    bam_file_name=`echo "${inbam}"|sed 's/.bam//g'`

    if [ ! -f ${inbam}.bai ]; then
        if [ -f \${bam_file_name}.bai ]; then
            mv \${bam_file_name}.bai ${inbam}.bai
        else
            samtools sort -o \${bam_file_name}_sorted.bam ${inbam}
            mv \${bam_file_name}_sorted.bam ${inbam}
            samtools index ${inbam}
        fi
    fi

    if [ "${workflow.profile}" == "test" ]; then
        faster exhunter -i ${inbam} -o ${meta.id} -r ${ref} -c ${test_variant_catalog}
    else
        faster exhunter -i ${inbam} -o ${meta.id} -r ${ref}
    fi
    """
}
