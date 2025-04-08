process info_check {
    label 'process_single'
    publishDir "${params.outdir}/info_check", mode: 'copy'
    input:
    path(sample_sheet)
    path(order_info)
    conda NXF_OFFLINE == 'true' ?
        "${params.conda_env_path}/envs/RapidQC_preprocessing":
        "${baseDir}/conf/preprocessing.yml"    
    output:
    path("${params.prefix}.sample_sheet.valid.merged.csv"), emit:ch_valid_samplesheet_path
    
    script:

    """
    #!/usr/bin/env python
    import pandas as pd
    import os

    # Define required columns
    required_columns = {
        '${sample_sheet}': [
            'UniqueKey',
            'fastq_1',
            'fastq_2'
        ]
    }

    # Optional columns for order info
    order_info_columns = [
        'SampleID',
        'Project',
        'Lane'
    ]

    try:
        # Read sample sheet
        samplesheet_df = pd.read_csv('${sample_sheet}')
        if not all(col in samplesheet_df.columns for col in required_columns['${sample_sheet}']):
            raise ValueError(f"Missing required columns in ${sample_sheet}. Required: {required_columns['${sample_sheet}']}")
    except Exception as e:
        print(f"Error loading ${sample_sheet}: {e}")
        exit(1)

    # Initialize merged dataframe with sample sheet
    merged_df = samplesheet_df.copy()

    # If order info exists, try to merge and create prefix
    if os.path.exists('${order_info}'):
        try:
            order_info_df = pd.read_csv('${order_info}', sep='\\t')
            if all(col in order_info_df.columns for col in order_info_columns):
                # Merge on SampleID if present in both
                if 'SampleID' in samplesheet_df.columns:
                    merged_df = pd.merge(samplesheet_df, order_info_df, on='SampleID', how='left')
                    # Create prefix from order info where available
                    merged_df['Prefix'] = merged_df.apply(
                        lambda row: f"{row['Project']}.{row['SampleID']}.L{row['Lane']}"
                        if pd.notna(row.get('Project')) and pd.notna(row.get('SampleID')) and pd.notna(row.get('Lane'))
                        else row['UniqueKey'],
                        axis=1
                    )
                else:
                    merged_df['Prefix'] = merged_df['UniqueKey']
            else:
                merged_df['Prefix'] = merged_df['UniqueKey']
        except Exception as e:
            print(f"Warning: Error processing order info file: {e}")
            merged_df['Prefix'] = merged_df['UniqueKey']
    else:
        merged_df['Prefix'] = merged_df['UniqueKey']

    # Save the merged dataframe
    merged_df.to_csv('${params.prefix}.sample_sheet.valid.merged.csv', index=False)
    """
}
