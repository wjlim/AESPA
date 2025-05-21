process LIMS_API_POST {
    label 'process_single'
    tag "LIMS API call for ${meta.id}"
    conda params.conda_env_path ?
        "${params.conda_env_path}/preprocessing":
        "${baseDir}/conf/preprocessing.yml"
    container "docker.io/cerutx/aespa:latest"

    input:
    tuple val(meta), path(json_file)

    output:
    tuple val(meta), path(json_file), emit:ch_json_file
    tuple val(meta), path("response.json"), emit:ch_api_response_json, optional: true

    script:
    // def api_address = params.lims_api_address
    // def api_key = params.api_key
    """
    lims_post.sh ${json_file} > response.json
    transform.py ${json_file} ${json_file}.out.json
    lims_qc_post.sh ${json_file}.out.json >> response.json
    """
}
