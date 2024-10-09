process LIMS_API_POST {
    label 'process_single'
    // secret 'api_key'
    publishDir "${params.outdir}/${meta.sample}/${params.prefix}", mode: 'copy'
    tag "LIMS API call for ${meta.id}"
    conda NXF_OFFLINE == 'true' ?
        "${params.conda_env_path}/envs/RapidQC_preprocessing":
        "${baseDir}/conf/preprocessing.yml"
    input:
    tuple val(meta), path(json_file)

    output:
    tuple val(meta), path("${meta.id}.response.json"), emit:ch_api_response_json
    tuple val(meta), path("${meta.id}.isaac.log"), emit:ch_isaac_response_json, optional: true
    tuple val(meta), path("modified_backup_script.${meta.order}.${meta.sample}.${meta.id}.csv"), emit:ch_isaac_script, optional: true
    script:
    def api_address = params.lims_api_address
    def api_key = params.api_key
    """
    xxFreemixAsn=\$(jq -r '.[0].xxFreemixAsn' ${json_file})
    if (( \$(echo "\$xxFreemixAsn > 0.05" | bc -l) )) || (( \$(echo "\$xxFreemixAsn == 0" | bc -l) )); then
        echo "xxFreemixAsn value (\$xxFreemixAsn) is greater than 0.05 or equal to 0. Running backup script."
        sample_sheet_path=\$(cat ${params.backup_script}|cut -d ' ' -f 4)
        escaped_sample_sheet=\$(cat <(head -n 1 \${sample_sheet_path}) <(grep ${meta.id} \${sample_sheet_path}) > escaped_sample_sheet.csv)
        awk '{print \$1,\$2,\$3,"escaped_sample_sheet",\$4,\$5,\$6,\$7,\$8,\$9,\$10}' ${params.backup_script} > modified_backup_script.${meta.order}.${meta.sample}.${meta.id}.csv
        sh modified_backup_script.${meta.order}.${meta.sample}.${meta.id}.csv > ${meta.id}.isaac.log
        touch ${meta.id}.response.json
    else
        curl -X POST \\
        ${api_address} \\
        -H "Content-Type: application/json" \\
        -H "X-API-KEY: ${api_key}" \\
        -d @${json_file} \\
        -k > ${meta.id}.response.json
    fi
    """
}
