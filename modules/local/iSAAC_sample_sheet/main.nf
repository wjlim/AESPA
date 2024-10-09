process CREATE_FASTQINPUT_SAMPLESHEET {
    tag "create iSAAC samplesheet for ${meta.id}"

    input:
    tuple val(meta), path(preprocessed_dir)

    output:
    tuple val(meta), path("${meta.id}_iSAAC_input.csv"), emit: ch_isaac_samplesheet

    script:
    def recipe = meta.recipe.split('-')
    def simplified_recipe = "${recipe[0]}-${recipe[3]}"

    """
    echo "FCID,Lane,SampleID,SampleRef,Index,Description,Control,Recipe,Operator,Project" > ${meta.id}_iSAAC_input.csv
    echo "${meta.fc_id},${meta.lane},${meta.sample},${meta.sample_ref},,${meta.desc},${meta.control},${simplified_recipe},${meta.operator},${meta.order}" >> ${meta.id}_iSAAC_input.csv
    """
}