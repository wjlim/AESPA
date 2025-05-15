process variant_call {
    label "process_medium"
    tag "strelka variant call for ${meta.id}"
    conda (params.conda_env_path ? "${params.conda_env_path}/variant_call" : "${moduleDir}/environment.yml")

    input:
    tuple val(meta), path(inbam), path(inbai), path(ref), path(ref_fai), path(ref_dict)

    output:
    tuple val(meta),  path( "*.vcf.gz*"), emit: raw_vcf_file

    script:
    """
    set -e
    echo -e "[StrelkaGermline]\nmaxIndelSize = 49\nminMapq = 20\nisWriteRealignedBam = 0\nextraVariantCallerArguments =" \
    > configureStrelkaGermlineWorkflow.py.ini

    configureStrelkaGermlineWorkflow.py \\
        --config=configureStrelkaGermlineWorkflow.py.ini \\
        --bam=${inbam} \\
        --referenceFasta=${ref} \\
        --runDir=VCF
    wait

    python2 \\
    VCF/runWorkflow.py \\
        -m local \\
        -j ${task.cpus} \\
        --quiet
    wait
    mv VCF/results/variants/*.vcf.gz* .
    wait
    touch dummy.vcf.gz
    """
}
