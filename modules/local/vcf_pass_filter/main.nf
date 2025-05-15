process pass_filter {
    label "process_single"
    tag "pass filter for ${meta.id}"
    conda (params.conda_env_path ? "${params.conda_env_path}/variant_call" : "${moduleDir}/environment.yml")

    input:
    tuple val(meta), path( raw_vcf_file)

    output:
    tuple val(meta), path("all_passed_variants.vcf"), emit: filtered_vcf

    script:
    """
    set +e
    gzip -dc genome.vcf.gz \
        | extract_variants \
        | awk '\$0 ~ /^#/ || \$7 ~/PASS/' \
        > all_passed_variants.vcf

    touch all_passed_variants.vcf
    """
}
