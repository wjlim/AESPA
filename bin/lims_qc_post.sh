#! /bin/bash
api_address='https://api.psomagen.com/api/private/dataQc/saveDataQc'
api_key='Initial0)'
json_file=$1

curl -X POST \
${api_address} \
-H "Content-Type: application/json" \
-H "X-API-KEY: ${api_key}" \
-d @${json_file} \
-k
