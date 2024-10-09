process variant_call {
    label "process_medium"
    tag "strelka variant call for ${meta.id}"
    publishDir "${params.outdir}/${meta.sample}/${params.prefix}", mode: 'copy'
    conda NXF_OFFLINE == 'true' ?
        "${params.conda_env_path}/envs/variant_call":
        "${baseDir}/conf/strelka_variant_call.yml"
    
    input:
    tuple val(meta), path(out_bam), path(out_bai), path(ref), path(ref_fai), path(ref_dict)

    output:
    tuple val(meta),  path( "VCF/results/variants/variants.vcf.gz"), emit: raw_vcf_file

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