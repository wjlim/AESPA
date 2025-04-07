#!/bin/bash
orderNumber=$1
sampleName=$2
merge_dir=/mnt/lustre2/Analysis/BI/WholeGenomeReSeq/${orderNumber}/${sampleName}/merge_analysis
cd ${merge_dir}
/cm/shared/apps/sge/2011.11p1/bin/linux-x64/qsub -l qname=all.q -N M.Raw.${sample_name} -cwd -pe peXMAS 16 -o std.out -e err.out -S /bin/bash /mnt/lustre2/Tools/WGS_Analysis/Pipeline/iSAAC4/scripts/iSAAC4.sh  ${merge_dir}
