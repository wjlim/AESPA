process ISAAC_PROCESS {
    label 'process_medium'
    // tag "${meta.order}.${meta.sample}.${meta.fc_id}.L00${meta.lane}"
    // publishDir "${params.outdir}", mode: 'copy'
    input:
    tuple val(meta), path(json_file)
    output:
    tuple val(meta), path('run.isaac.cmd.sh'), emit:ch_isaac_cmd
    tuple val(meta), path("*.log"), emit: ch_isaac_log
    script:
    """
    dest_path=${params.wgs_dest_path}/${meta.order}/${meta.sample}/${params.prefix}
    sample_sheet_isaac_input=\${dest_path}/fastqinput_SampleSheet.csv
    sample_sheet_input=\${dest_path}/SampleSeet.csv
    order_info_input=\${dest_path}/OrderInfo.txt
    echo "FCID,Lane,SampleID,SampleRef,Index,Description,Control,Recipe,Operator,Project" > \${sample_sheet_isaac_input}
    echo "${meta.fc_id},${meta.lane},${meta.sample},${meta.sample_ref},,${meta.desc},${meta.control},${simplified_recipe},${meta.operator},${meta.order}" >> \${sample_sheet_isaac_input}
    cat <(head -n 1 ${params.sample_sheet}) <(grep ${meta.sample} ${params.sample_sheet}) > \${sample_sheet_input}
    cat <(head -n 1 ${params.order_info}) <(grep ${meta.sample} ${params.order_info}) > \${order_info_input}
    mkdir -p \${dest_path} 
    #/cm/shared/apps/sge/2011.11p1/bin/linux-x64/qsub -l qname=all.q -N N.Raw.CANDAS-SMPD_000070_s1 -cwd -pe peXMAS 16 -o std.out -e err.out -S /bin/bash /mnt/lustre2/Tools/WGS_Analysis/Pipeline/iSAAC4/scripts/iSAAC4.sh  /mnt/lustre2/Analysis/BI/WholeGenomeReSeq/AN00021327/CANDAS-SMPD_000070_s1/20241029_22J22VLT4_1
    """
}