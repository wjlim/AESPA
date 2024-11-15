process DEMUX_CHECK {
    label "process_single"
    tag "Demux check and merging raw data for ${meta.order}.${meta.sample}.${meta.fc_id}.L00${meta.lane}"
    publishDir "${wgs_dest_path}/${meta.sample}/merged_analysis", mode:'copy', overwrite: true

    input:
    tuple val(meta), path(qc_report)
    path(project_path)
    path(wgs_dest_path)

    output:
    tuple val(meta), path("${meta.sample}_1.fastq.gz"), path("${meta.sample}_2.fastq.gz"), emit:ch_merged_samplesheet
    tuple val(meta), path('passed_info.txt'), emit:passed_info
    tuple val(meta), path('passed_forward_reads.txt'), path('passed_reverse_reads.txt'), emit:passed_raw_data_info

    script:

    """
    #!/bin/bash
    confirm_files=\$(ls ${project_path}/${meta.order}/*/${meta.sample}/confirm.txt)
    for fname in \$confirm_files
    do
        tail -n+2 \$fname |awk -v FS='\t' -v OFS=',' '\$NF~/PASS/ {print \$0}' >> passed_info.txt
    done

    for row in \$(cat passed_info.txt)
    do
        sampleid=\$(cut -d ',' -f 2 \$row)
        fc_dir=\$(cut -d ',' -f 3 \$row)
        fc_id=\$(cut -d '_' -f -2 \$fc_dir)
        lane=\$(cut -d ',' -f 4 \$row)
        fastq_1=\$(readlink -f ${project_path}/${meta.order}/\$fc_dir/${meta.sample}/LaneFastq/\${fc_id}_\${sampleid}_L00\${lane}_1.fastq.gz) >> passed_forward_reads.txt
        fastq_2=\$(readlink -f ${project_path}/${meta.order}/\$fc_dir/${meta.sample}/LaneFastq/\${fc_id}_\${sampleid}_L00\${lane}_2.fastq.gz) >> passed_reverse_reads.txt
    done

    cat \$(cat passed_forward_reads.txt ) > ${meta.sample}_1.fastq.gz
    cat \$(cat passed_reverse_reads.txt ) > ${meta.sample}_2.fastq.gz
    """
}