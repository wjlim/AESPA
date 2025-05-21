#!/usr/bin/env python
import json
import sys

def transform_json(input_file, output_file):
    with open(input_file, 'r') as f:
        data = json.load(f)
    transformed_data = []
    for item in data:
        values = []
        for key, value in item.items():
            if key != 'uniqLibNo':
                values.append(str(value)[:20])

        new_item = {
            "dataType": "AS",
            "uniqLibNo": item['uniqLibNo'],
            "values": values
        }
        transformed_data.append(new_item)

    with open(output_file, 'w') as f:
        json.dump(transformed_data, f, indent=2)

input_file = sys.argv[1]
output_file = sys.argv[2]
transform_json(input_file, output_file)
