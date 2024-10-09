process pass_filter {
    label "process_single"
    tag "pass filter for ${meta.id}"
    publishDir "${params.outdir}/${meta.sample}/${params.prefix}", mode: 'copy'
    conda NXF_OFFLINE == 'true' ?
        "/mmfs1/lustre2/BI_Analysis/wjlim/anaconda3/envs/variant_call":
        "${baseDir}/conf/strelka_variant_call.yml"

    input:
    tuple val(meta), path( raw_vcf_file)

    output:
    tuple val(meta), path("all_passed_variants.vcf"), emit: filtered_vcf

    script:
    """
    gzip -dc ${raw_vcf_file} \\
        | extract_variants \\
        | awk '\$0 ~ /^#/ || \$7 ~/PASS/' \\
        > all_passed_variants.vcf
    """
}
