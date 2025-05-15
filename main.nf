#!/usr/bin/env nextflow

nextflow.enable.dsl = 2

include { AESPA } from "${baseDir}/workflow/aespa.nf"

workflow {
    main:
        if (params.genome && params.genomes.containsKey(params.genome)) {
        fasta = params.genomes[params.genome].fasta
        fai = params.genomes[params.genome].fai
        dict = params.genomes[params.genome].dict
        bwamem2_index = params.genomes[params.genome].bwamem2_index
        isaac_index = params.genomes[params.genome].isaac_index
    }
    def aligner = params.aligner
    def index = params.genomes[params.genome][aligner + "_index"]
    Channel.of(
        tuple(
            file(fasta),
            file(fai),
            file(dict),
        ))
        .set { ch_ref_path }

    Channel.fromPath(params.sample_sheet)
        .splitCsv(header:true)
        .map {
            row ->
            def meta = [
                id:row.sample_id,
                prefix:row.prefix,
                fastq_1:row.fastq_1,
                fastq_2:row.fastq_2,
                recipe: row.recipe ?: "151-10-10-151",
                order: row.order ?: row.sample_id
            ]
            return tuple( meta, file(row.fastq_1), file(row.fastq_2))
        }
        .set { ch_samplesheet }
    AESPA(ch_samplesheet, ch_ref_path, index, aligner,true)

}
