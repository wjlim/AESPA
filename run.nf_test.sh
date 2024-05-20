#!/bin/bash
outdir=test
work=$outdir/work
json_file=input.json
nf_temp=$outdir/temp
export NXF_WORK=$work
export NXF_TEMP=$temp
export NXF_OFFLINE=true

mkdir -p $outdir
mkdir -p $work
mkdir -p $nf_temp

nextflow run main.nf \
    -profile sge_local_env \
    --json_file $json_file \
    -with-report "$outdir/reports/nf_out.report.html" \
    -with-dag "$outdir/reports/flowchart.png" \
    -with-timeline "$outdir/reports/nf_out.timeline.report.html" \
    --log "$outdir/nxf.log" \
    -resume \
    -dump-hashes "${outdir}/.dump.json" \
    -with-trace "$outdir/reports/trace.txt"\
    -bg \
    &> $outdir/run.log.txt
