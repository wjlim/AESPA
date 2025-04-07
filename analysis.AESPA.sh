#!/bin/bash
if [ $# -ne 7 ] ;then
        echo "USAGE   : ${0} [path of run directory] [path of SampleSheet.csv] [path of OrderInfo.txt] [path of demulti output directory] [use-bases-mask] [PlateID] [Corp.code]"
        echo "Example : ${0} /mnt/lustre1/Instruments/NovaSeq_03/190702_A00718_0078_AHM2FGDSXX /data/wwwdata/HISEQ_IMPORT/180821_ST-E00127_0808_AHMTTVCCXY_Directory_1.csv \
                           /lustre2/Analysis/Project/[OrderNumber]/OrderInfo.txt /lustre2/Pipeline/HiSeqX_05/180821_ST-E00127_0808_AHMTTVCCXY/Directory_1 y151,i8,i8,y151 HNP18111700401 1000"
        exit
fi

#############################
## Argument Configurations ##
#############################

#STORAGE=`readlink -e ${0} | sed 's/\/mnt//g' | cut -d "/" -f2`
STORAGE=`readlink -e ${0} | sed 's/\/mnt//g' | cut -d "/" -f3`

if [ ${STORAGE} == "lustre2" ];then QNAME="all.q"; num_slot=16; source /cm/shared/apps/sge/2011.11p1/default/common/settings.sh
elif [ ${STORAGE} == "garnet" ];then QNAME="bi1.q"; num_slot=54; source /mnt/garnet/ge2011.11/default/common/settings.sh
else echo "Please Chekc SEASON & QNAME"; exit
fi


run_dir_path=${1}
sample_sheet_path=${2}
order_info_path=${3}
dem_dir_path=${4}
bases_mask=${5}
plate_id=${6}
corp_code=${7}

flowcell_dir_name=`echo ${sample_sheet_path} | rev | cut -d"/" -f1 | rev | cut -d "." -f1`
orderNumber=`cat ${order_info_path} | tail -n1 | cut -f2`
sample_sheet_name="${flowcell_dir_name}_${orderNumber}.csv"
order_info_name="${flowcell_dir_name}_${orderNumber}.txt"

new_sample_sheet_path="/${STORAGE}/Tools/bcl2fastq/analysis_v3_210316_with_kdna_with_MGI/log/samplesheet/"
kdna_sample_sheet_path="/${STORAGE}/Tools/bcl2fastq/analysis_v3_210316_with_kdna_with_MGI/log/samplesheet/KDNA"

get_value_from_file() {
    local column_name="$1"
    local file_name="$2"
        local sep="${3:-,}"
    awk -F "${sep}" -v col="${column_name}" 'NR == 1{for (i=1;i<=NF;i++){if ($i == col) {col_index = i}}}NR==2{print $col_index}' ${file_name}
}
application=$(get_value_from_file "ApplicationType" ${order_info_path} '\t')
species=$(get_value_from_file "Species" ${order_info_path} '\t')
description=$(get_value_from_file "Description" ${order_info_path} '\t')
service_group=$(get_value_from_file "Service Group" ${order_info_path} '\t')

#############################
##### Pipeline Classify #####
#############################

header=`head -1 ${sample_sheet_path}`
kdnaPipe=""
if [[ "$header" == *"Customer ID"* ]]; then
        customerId_col_N=`head -1 ${sample_sheet_path} | sed "s/,/\n/g" | grep -n "Customer ID" | cut -d ":" -f1`
        kdnaPipe=`cut -d "," -f${customerId_col_N} ${sample_sheet_path} | grep "jhpark706"`
fi

if [ -n "${kdnaPipe}" ];then
        #############################
        ##### for KDNA Pipeline #####
        #############################
        cat ${new_sample_sheet_path}/SampleSheet.header > ${kdna_sample_sheet_path}/${flowcell_dir_name}_${orderNumber}.csv
        cat ${new_sample_sheet_path}/OrderInfo.header > ${kdna_sample_sheet_path}/${flowcell_dir_name}_${orderNumber}.txt
        grep ${orderNumber} ${sample_sheet_path} >> ${kdna_sample_sheet_path}/${flowcell_dir_name}_${orderNumber}.csv

        for id in `cut -d"," -f3 ${kdna_sample_sheet_path}/${flowcell_dir_name}_${orderNumber}.csv | grep -v SampleID`;
        do
                grep -P "^$id\t" ${order_info_path} >> ${kdna_sample_sheet_path}/${flowcell_dir_name}_${orderNumber}.txt
        done

        kdna_order_info_path="${kdna_sample_sheet_path}/${flowcell_dir_name}_${orderNumber}.txt"
        kdna_sample_sheet_path="${kdna_sample_sheet_path}/${flowcell_dir_name}_${orderNumber}.csv"
        mkdir -p /mnt/lustre2/Analysis/BI/WholeGenomeReSeq/${orderNumber}
        chmod 777 /mnt/lustre2/Analysis/BI/WholeGenomeReSeq/${orderNumber}

        cd /mnt/lustre2/Tools/bcl2fastq/analysis_v3_210316_with_kdna_with_MGI/log/KDNA
        /mnt/lustre2/Tools/WGS_Analysis/Programs/Java/jdk1.7.0_45/bin/java -cp /lustre2/Tools/bcl2fastq/analysis_v3_210316_with_kdna_with_MGI/hidden/ KDNA ${kdna_order_info_path} ${plate_id} ${corp_code} ${flowcell_dir_name} 
else
        ################################
        ##### for General Pipeline #####
        ################################
        cat ${new_sample_sheet_path}/SampleSheet.header > ${new_sample_sheet_path}/${flowcell_dir_name}_${orderNumber}.csv
        cat ${new_sample_sheet_path}/OrderInfo.header > ${new_sample_sheet_path}/${flowcell_dir_name}_${orderNumber}.txt
        grep ${orderNumber} ${sample_sheet_path} >> ${new_sample_sheet_path}/${flowcell_dir_name}_${orderNumber}.csv

        for id in `cut -d"," -f3 ${new_sample_sheet_path}/${flowcell_dir_name}_${orderNumber}.csv | grep -v SampleID`;
        do
                grep -P "^$id\t" ${order_info_path} >> ${new_sample_sheet_path}/${flowcell_dir_name}_${orderNumber}.txt
        done

        new_order_info_path="${new_sample_sheet_path}/${flowcell_dir_name}_${orderNumber}.txt"
        new_sample_sheet_path="${new_sample_sheet_path}/${flowcell_dir_name}_${orderNumber}.csv"
        run_folder_id=$(echo $(basename ${sample_sheet_path})|cut -d _ -f 1,4,6|sed 's/.csv//g'| sed 's/_\(B\|A\)/_/')
        wgs_outpath="/mmfs1/lustre2/Analysis/BI/WholeGenomeReSeq"
        sample_sheet_prefix=$(basename ${sample_sheet_path})

        cd /${STORAGE}/Tools/bcl2fastq/analysis_v3_210316_with_kdna_with_MGI/log/lims
        if [[ "${application}" =~ "Whole Genome Resequencing" ]];then
                if [[ "${species}" =~ "Human" && "${description}" =~ "Fastq only" && "${service_group}" != "CLIA" ]]; then

                        # source /mmfs1/lustre2/BI_Analysis/bi2/anaconda3/etc/profile.d/conda.sh
                        # conda activate

                        export NXF_WORK="${wgs_outpath}/${orderNumber}/nxf_work"
                        export NXF_LOG_FILE="${wgs_outpath}/${orderNumber}/${run_folder_id}.nextflow.log"
                        export NXF_OFFLINE='true'
                        export NXF_DEBUG=0
                        echo "working directory: ${NXF_WORK}"
                        echo "log file : ${NXF_LOG_FILE}"
                        mkdir -p ${NXF_WORK}
                        cp ${sample_sheet_path} ${NXF_WORK}
                        isaac_command="sh /${STORAGE}/Tools/bcl2fastq/analysis_v3_210316_with_kdna_with_MGI/subWGS.sh ${run_dir_path} ${sample_sheet_prefix} ${new_order_info_path} ${dem_dir_path} ${bases_mask} ${plate_id} ${corp_code}"
                        backup_cmd_path=${wgs_outpath}/${orderNumber}/${run_folder_id}.isaac_cmd.sh
                        echo ${isaac_command} > ${backup_cmd_path}
                        aespa_command="nohup nextflow run /mmfs1/lustre2/BI_Analysis/bi2/AESPA/main.nf -profile sge --outdir ${wgs_outpath}/${orderNumber} --sample_sheet ${NXF_WORK}/${sample_sheet_prefix} --order_info ${order_info_path} --run_dir ${dem_dir_path} --run_dir_path ${run_dir_path} --prefix ${run_folder_id}"
                        # backup_command=$(echo ${submit_command}|sed 's/-bg/-bg -resume/g')
                        AESPA_cmd_path=${wgs_outpath}/${orderNumber}/${run_folder_id}.AESPA_cmd.sh
                        echo -e "source /mmfs1/lustre2/BI_Analysis/bi2/anaconda3/etc/profile.d/conda.sh\nconda activate\nexport NXF_WORK=${wgs_outpath}/${orderNumber}/nxf_work\nexport NXF_LOG_FILE=${wgs_outpath}/${orderNumber}/${run_folder_id}.nextflow.log\nexport NXF_OFFLINE='true'\nexport NXF_DEBUG=3\n${aespa_command}" > ${AESPA_cmd_path}
                        submit_command="qsub -v PATH=$PATH -l qname=bi.q -N ASP-${plate_id}.${orderNumber} -cwd -pe peXMAS 1 -o ${wgs_outpath}/${orderNumber}/${run_folder_id}.run.log -e ${wgs_outpath}/${orderNumber}/${run_folder_id}.run.err -S /bin/bash ${AESPA_cmd_path}"
                        #qsub -v PATH=$PATH -l qname=${qname} -N custom_wj -cwd -pe peXMAS ${slot} -o ${n_values%.sh}.log -e ${n_values%.sh}.err -S /bin/bash
                        echo "Resume_cmd:${AESPA_cmd_path}"
                else 
                        submit_command="sh /${STORAGE}/Tools/bcl2fastq/analysis_v3_210316_with_kdna_with_MGI/subWGS.sh ${run_dir_path} ${new_sample_sheet_path} ${new_order_info_path} ${dem_dir_path} ${bases_mask} ${plate_id} ${corp_code}"
                        # submit_command="Please Check Application Type"
                fi
        else
                echo "Please Check Application Type"
                exit 1
        fi
        # ${submit_command}
        echo ${submit_command}
        eval ${submit_command} 
        echo "`date` : ${submit_command}" >> /${STORAGE}/Tools/bcl2fastq/analysis_v3_210316_with_kdna_with_MGI/log/analysis_submit.log
fi