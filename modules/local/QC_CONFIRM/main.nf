process QC_CONFIRM {
    label 'process_single'
    tag "QC_confirmation for ${meta.sample}"
    conda NXF_OFFLINE == 'true' ?
        "${params.conda_env_path}/envs/RapidQC_preprocessing":
        "${baseDir}/conf/preprocessing.yml"
    publishDir "${params.outdir}/${meta.sample}/merge_analysis/Fastq", mode: 'copy'
    input:
    tuple val(meta), path(api_response)

    output:
    tuple val(meta), path('passed_df.csv'), emit: ch_merged_samplesheet
    
    script:
    def wgs_dest_path = params.wgs_dest_path
    def project_path = params.project_path
    def run_dir = params.prefix
    """
    #!/usr/bin/env python
    from glob import glob
    import pandas as pd

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
            return pd.DataFrame()
        merged_df = pd.merge(wgs_df, demux_df, on=['Project', 'SampleID', 'AnalysisPath', 'Lane'])
        merged_df = merged_df.apply(lambda x: x.str.strip() if x.dtype == "object" else x)
        return merged_df[(merged_df['PASS/FAIL'] != 'FAIL') & (merged_df['Result'] == 'PASS')]

    def remove_duplicates(df1, df2, keys):
        return df1[~df1.set_index(keys).index.isin(df2.set_index(keys).index)]

    # Define paths and get files
    wgs_qc_path = f"${wgs_dest_path}/${meta.order}/${meta.sample}/*/confirm.txt"
    demux_path = f"${project_path}/${meta.order}/*/${meta.sample}/confirm.txt"
    wgs_files = glob(wgs_qc_path)
    demux_files = glob(demux_path)

    # Process WGS data
    wgs_df = merge_dataframes(wgs_files)
    
    # Create target WGS dataframe
    target_wgs_df = pd.DataFrame({
        'Project': '${meta.order}',
        'SampleID': '${meta.sample}',
        'AnalysisPath': '${run_dir}',
        'Lane': f'L00${meta.lane}',
        'PASS/FAIL': 'PASS',
        'Result' : 'PASS'
    }, index=[999])

    # Remove duplicates from wgs_df that are present in target_wgs_df
    wgs_df = remove_duplicates(wgs_df, target_wgs_df, ['Project', 'SampleID', 'AnalysisPath', 'Lane'])

    # Process demux data
    demux_colnames = ['Project', 'SampleID', 'AnalysisPath', 'Lane', 'Result']
    demux_df = process_demux_df(merge_dataframes(demux_files), demux_colnames)

    # Merge and filter dataframes
    passed_df = merge_and_filter_dfs(wgs_df, demux_df)

    # Concatenate with target WGS dataframe and save result
    passed_df.to_csv('passed_df.csv', index=False)
    """
}