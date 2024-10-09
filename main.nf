#!/usr/bin/env nextflow
import groovy.json.JsonSlurper
include { AESPA                } from "${baseDir}/workflow/aespa.nf"
include { FIND_RAW_DATA        } from "${baseDir}/modules/local/find_raw_data"
include { INPUT_CHECK          } from "${baseDir}/subworkflow/local/input_check"
include { QC_CHECK             } from "${baseDir}/subworkflow/local/QC_CHECK"
include { MAKE_DELIVERABLES    } from "${baseDir}/subworkflow/local/make_deliverables"

workflow {
    main:
    def config = new JsonSlurper().parseText(file(params.ref_conf).text)
    INPUT_CHECK(
        file(params.order_info),
        file(params.sample_sheet),
        file(params.run_dir),
    )

    Channel.of(
        tuple(
            file(config.fasta),
            file(config.fai),
            file(config.dict)
        ))
        .set { ch_ref_path }

    Channel.of(
        tuple(
            file(config.bwamem2_index),
            file(config.fasta)
            )
        )
        .set { ch_bwamem2_index_path }

    INPUT_CHECK.out.ch_merged_samplesheet
        .map {meta, fastq_1, fastq_2 -> 
            [meta, fastq_1, fastq_2]
        }
        .filter {meta, fastq_1, fastq_2 ->
            meta.app == 'Whole Genome Resequencing' &&
            meta.desc == 'Fastq only' &&
            meta.species == 'Human' &&
            meta.service_group != 'CLIA'
        }
        .set { ch_samplesheet_mix }
    AESPA(ch_samplesheet_mix, ch_ref_path, ch_bwamem2_index_path)
    QC_CHECK(AESPA.out.ch_qc_report)
    MAKE_DELIVERABLES(QC_CHECK.out.ch_api_response)
}
