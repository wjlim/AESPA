process LIMS_API_POST {
    label 'process_single'
    executor "local"

    tag "LIMS API call for ${meta.order}.${meta.sample}.${meta.fc_id}.L00${meta.lane}"
    conda NXF_OFFLINE == 'true' ?
        "${params.conda_env_path}/envs/RapidQC_preprocessing":
        "${baseDir}/conf/preprocessing.yml"
    input:
    tuple val(meta), path(json_file)
    
    output:
    tuple val(meta), path("${meta.id}.response.json"), emit:ch_api_response_json
    script:
    def api_address = params.lims_api_address
    def api_key = params.api_key
    def max_attempts = task.ext.args.max_attempts ?: 3
    def sleep_time = task.ext.args.sleep_time ?: 300
    
    """
    attempt=1
    max_attempts=${max_attempts}
    success=false

    while [ \$attempt -le \$max_attempts ] && [ "\$success" = "false" ]; do
        curl -X POST \\
        ${api_address} \\
        -H "Content-Type: application/json" \\
        -H "X-API-KEY: ${api_key}" \\
        -d @${json_file} \\
        -k > ${meta.id}.response.json

        if grep -q '"data":"Success","error":null' ${meta.id}.response.json; then
            success=true
            echo "API call successful on attempt \$attempt"
        else
            if [ \$attempt -lt \$max_attempts ]; then
                echo "API call failed on attempt \$attempt. Waiting ${sleep_time} seconds before retry..."
                sleep ${sleep_time}
                attempt=\$((attempt + 1))
            else
                echo "API call failed after \$max_attempts attempts"
                exit 1
            fi
        fi
    done
    """
}
