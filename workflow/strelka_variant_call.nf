#!/usr/bin/env nextflow

nextflow.enable.dsl=2

workflow variant_calling {
    take:
    bam_ch
    ref_ch

    main:
    variant_call(bam_ch, ref_ch)
    pass_filter(bam_ch, variant_call.out.raw_vcf_file)

    emit:
    strelka_vcf = pass_filter.out
    raw_vcf = variant_call.out.raw_vcf_file
}

process variant_call {
    label "process_medium"
    tag "strelka variant call for ${sample_id}"
    publishDir "${output_dir}", mode: "copy"
    conda "${basdDir}/workflow/strelka_variant_call.yml"
    
    input:
    tuple val(sample_id), path(out_bam), path(out_bai), path(output_dir)
    tuple path(ref), path(ref_fai), path(ref_dict)

    output:
    path "VCF/results/variants/variants.vcf.gz", emit: raw_vcf_file
    path "VCF/results/variants/*.gz"
    path "VCF/results/variants/*.gz.tbi"    

    script:
    """
    echo -e "[StrelkaGermline]\nmaxIndelSize = 49\nminMapq = 20\nisWriteRealignedBam = 0\nextraVariantCallerArguments =" \
    > configureStrelkaGermlineWorkflow.py.ini
    
    configureStrelkaGermlineWorkflow.py \\
        --config=configureStrelkaGermlineWorkflow.py.ini \\
        --bam=${out_bam} \\
        --referenceFasta=${ref} \\
        --runDir=VCF

    python2 \\
    VCF/runWorkflow.py \\
        -m local \\
        -j ${task.cpus} \\
        --quiet
    """
}

process pass_filter {
    label "process_single"
    tag "pass filter for ${sample_id}"
    conda "${basdDir}/workflow/strelka_variant_call.yml"
    publishDir "${output_dir}/stat_outputs", mode: "copy"
    publishDir "${output_dir}/VCF", mode: "copy"

    input:
    tuple val(sample_id), path(out_bam), path(out_bai), path(output_dir)
    path raw_vcf_file

    output:
    path "all_passed_variants.vcf", emit: filtered_vcf

    script:
    """
    gzip -dc ${raw_vcf_file} \\
        | extract_variants \\
        | awk '\$0 ~ /^#/ || \$7 ~/PASS/' \\
        > all_passed_variants.vcf
    """
}