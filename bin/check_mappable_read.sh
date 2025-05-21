#!/bin/bash
# Nancy addition to WGS pipeline so we can run BLAST on unmapped reads and delete BAM after to save storage space.

# time/date for logging purposes
time=`date +"%F_%T"`
date=`date +"%F_%T" | cut -d "_" -f1 | sed 's/-//g'`
date=${date:2}
time=`echo ${time} | cut -d "_" -f2 | sed 's/://g'`

work_dir=$1

order=`echo ${work_dir} | rev | cut -d "/" -f3 | rev`
sample=`echo ${work_dir} | rev | cut -d "/" -f2 | rev`
flowcell=`echo ${work_dir} | rev | cut -d "/" -f1 | rev`

# ===================================================================================

if [ ! -f ${work_dir}/${order}_${sample}.summary  ] ; then # if summary file not generate, then pipeline had some issue that needs checking.
        exit
fi

mappable=`cat ${work_dir}/${order}_${sample}.summary | grep "Mappable reads %" | awk {'print $8'}`

if [ "${mappable}" == "" ] ; then # If this stat is not here then some file somewhere has not generated and needs checking.
	exit
fi

#if [ $( echo " ${mappable} >= 90  " | bc ) -eq 1 ] ; then
#	rm ${work_dir}/IsaacAlignment/Projects/${order}/${sample}/sorted.bam
#fi

#if [ $( echo " ${mappable} >= 80  " | bc ) -eq 1 ] && [ $( echo " ${mappable} == 0  " | bc ) -eq 0 ] ; then # If mappable > 80%, then no need to run BLAST.
#	rm ${work_dir}/IsaacAlignment/Projects/${order}/${sample}/sorted.bam
#        exit
#fi

# ===================================================================================

align_dir="${work_dir}/IsaacAlignment/Projects/${order}/${sample}"

mkdir ${align_dir}/BLAST
ln -s ${align_dir}/sorted.bam ${align_dir}/BLAST/.

cd ${align_dir}/BLAST
sh /mnt/lustre2/BI_Analysis/nancy/wgs/tools/run_blast_unmapped.sh sorted.bam ${sample}
