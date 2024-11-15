process info_check {
    label 'process_single'
    input:
    path(sample_sheet)
    path(order_info)
    conda NXF_OFFLINE == 'true' ?
        "${params.conda_env_path}/envs/RapidQC_preprocessing":
        "${baseDir}/conf/preprocessing.yml"    
    output:
    path('sample_sheet.valid.merged.csv'), emit:ch_valid_samplesheet_path
    
    script:

    """
    #!/usr/bin/env python
    import pandas as pd
    expected_columns = {
        '${order_info}': [
            'SampleID',
            'Project',
            'Institute',
            'Customer',
            'Librarytype',
            'Description',
            'Platform',
            'Species',
            'SampleType',
            'ApplicationType',
            'RunningType',
            'RunScale',
            'Count',
            'GasketID',
            'Ref_ver',
            'SSBaitDesignID',
            'Contract',
            'Library Kit',
            'Library Protocol',
            'Service Group',
            'pl Id'
        ],
        '${sample_sheet}': [
            'FCID',
            'Lane',
            'SampleID',
            'SampleRef',
            'Index Seq',
            'Description',
            'Control',
            'Recipe',
            'Operator',
            'Project',
            'LibraryType',
            'Species',
            'ApplicationType',
            'OrderGrade',
            'RunScale',
            'UniqueKey',
            'fastq_1',
            'fastq_2'
        ]
    }

    try:
        order_info_df = pd.read_csv('${order_info}', sep='\t')
        if not all(col in order_info_df.columns for col in expected_columns['${order_info}']):
            raise ValueError("Missing columns in ${order_info}")
    except Exception as e:
        print(f"Error loading ${order_info}: {e}")
        exit(1)

    try:
        samplesheet_df = pd.read_csv('${sample_sheet}')
        if not all(col in samplesheet_df.columns for col in expected_columns['${sample_sheet}']):
            raise ValueError("Missing columns in ${sample_sheet}")
    except Exception as e:
        print(f"Error loading ${sample_sheet}: {e}")
        exit(1)
    merged_df = pd.merge(samplesheet_df.astype(str), order_info_df.astype(str), on='SampleID', how='left')
    if merged_df.shape[0] == 0:
        raise ValueError("No matching records found after merging sample sheet and order info")
    merged_df.to_csv('sample_sheet.valid.merged.csv', index = False)
    """
}
