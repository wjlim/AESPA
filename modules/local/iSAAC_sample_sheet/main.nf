process CREATE_FASTQINPUT_SAMPLESHEET {
    tag "create iSAAC samplesheet for ${meta.id}"
    conda (params.conda_env_path ? "${params.conda_env_path}/iSAAC_align" : "${moduleDir}/environment.yml")
    label 'process_single'

    input:
    tuple val(meta), path(preprocessed_dir)

    output:
    tuple val(meta), path("${meta.id}_iSAAC_input.csv"), emit: ch_isaac_samplesheet

    script:
    def simplified_recipe = "151-151"
    def fc_id = meta.fc_id ?: "test_fcid"
    def sample_ref = meta.sample_ref ?: "test_sample_ref"
    def control = meta.control ?: "N"
    def operator = meta.operator ?: "test_operator"
    def order = meta.order ?: "test_order"
    def description = meta.description ?: "test_description"
    """
    echo "FCID,Lane,SampleID,SampleRef,Index,Description,Control,Recipe,Operator,Project" > ${meta.id}_iSAAC_input.csv
    echo "${fc_id},1,${meta.id},${sample_ref},,${description},${control},${simplified_recipe},${operator},${order}" >> ${meta.id}_iSAAC_input.csv
    """
}
