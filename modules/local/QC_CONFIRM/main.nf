process QC_CONFIRM {
    label 'process_single'
    tag "QC_confirmation for ${meta.sample}"
    conda NXF_OFFLINE == 'true' ?
        "${params.conda_env_path}/envs/RapidQC_preprocessing":
        "${baseDir}/conf/preprocessing.yml"
    input:
    tuple val(meta), path(api_response)

    output:
    tuple val(meta), path('*.passed_df.csv'), emit: ch_confirmed
    
    script:
    def wgs_dest_path = params.wgs_dest_path
    def project_path = params.project_path
    def run_dir = params.prefix
    """
    #!/usr/bin/env python
    from glob import glob
    import pandas as pd
    import sys
    
    def merge_dataframes(file_list):
        dfs = [pd.read_table(fname).rename(columns=lambda x: x.strip()) for fname in file_list]
        return pd.concat(dfs, axis=0).astype(str) if dfs else pd.DataFrame()

    def process_demux_df(df, colnames):
        if df.empty:
            return pd.DataFrame(columns=colnames)
        df.columns = colnames
        df['Lane'] = df['Lane'].str.replace('R0', 'L00')
        return df

    def merge_and_filter_dfs(wgs_df, demux_df):
        if demux_df.empty:
            return wgs_df
        
        # Strip whitespace from string columns in both dataframes
        wgs_df = wgs_df.apply(lambda x: x.str.strip() if x.dtype == "object" else x)
        demux_df = demux_df.apply(lambda x: x.str.strip() if x.dtype == "object" else x)
        
        # Get unique rows based on required columns for each dataframe
        base_columns = ['Project', 'SampleID', 'AnalysisPath', 'Lane']
        
        wgs_unique = wgs_df.drop_duplicates(subset=base_columns)
        demux_unique = demux_df.drop_duplicates(subset=base_columns)
        
        # Merge the dataframes
        merged_df = pd.merge(
            wgs_unique[base_columns + ['PASS/FAIL']], 
            demux_unique[base_columns + ['Result']], 
            on=base_columns,
            how='outer'
        )
        
        return merged_df

    # Define paths and get files
    wgs_qc_path = f"${wgs_dest_path}/${meta.order}/${meta.sample}/*/confirm.txt"
    demux_path = f"${project_path}/${meta.order}/*/${meta.sample}/confirm.txt"
    wgs_files = glob(wgs_qc_path)
    demux_files = glob(demux_path)

    # Create target WGS dataframe
    target_wgs_df = pd.DataFrame({
        'Project': '${meta.order}',
        'SampleID': '${meta.sample}',
        'AnalysisPath': '${run_dir}',
        'Lane': f'L00${meta.lane}',
        'PASS/FAIL': 'PASS'
    }, index=[999])

    required_columns = ['Project', 'SampleID', 'AnalysisPath', 'Lane']

    # Process WGS data
    if len(wgs_files) == 0:
        wgs_df = target_wgs_df
    elif len(wgs_files) >= 1:
        wgs_df = merge_dataframes(wgs_files)
        wgs_df = pd.concat([target_wgs_df, wgs_df], axis = 0)
    else:
        print(f"${meta.sample} has malformed confirm.txt files")
        sys.exit(1)

    # Process demux data
    demux_colnames = ['Project', 'SampleID', 'AnalysisPath', 'Lane', 'Result']
    demux_df = process_demux_df(merge_dataframes(demux_files), demux_colnames)

    # Save intermediate results
    wgs_df.to_csv('wgs_df.csv', index=False)
    demux_df.to_csv('demux_df.csv', index=False)

    # Merge dataframes
    passed_df = merge_and_filter_dfs(wgs_df, demux_df)
    passed_df = passed_df[(passed_df['PASS/FAIL'] != 'FAIL') & (passed_df['Result'] != 'FAIL')]
    passed_df = passed_df.groupby(required_columns, as_index=False).first()

    # Save result
    passed_df.to_csv('${meta.sample}.passed_df.csv', index=False)
    """
}