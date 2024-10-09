process LIMS_QC_API_CALL {
    tag "${meta.id}"
    publishDir "${params.outdir}/${meta.sample}/${params.prefix}", mode: 'copy'
    
    input:
    tuple val(meta), path(qc_summary)
    
    output:
    tuple val(meta), path("${meta.id}_input.json"), emit: json_file
    
    script:

    """
    #!/usr/bin/env python3
    import json
    
    # Read QC summary file
    with open("${qc_summary}", 'r') as f:
        qc_data = dict(line.strip().split('\\t') for line in f)

    # Prepare API request payload
    payload = {
        "uniqLibNo": "${meta.id}",
        "resultPath": "${qc_summary}",
        "xxTread": qc_data["Total reads"],
        "xxRlength": qc_data["Read length (bp)"],
        "xxYie": qc_data["Total yield (Mbp)"],
        "xxRsize": qc_data["Reference size (Mbp)"],
        "xxTmeandepth": qc_data["Throughput mean depth (X)"],
        "xxDupread": qc_data["De-duplicated reads"],
        "xxDupread2": qc_data["De-duplicated reads % (out of total reads)"],
        "xxMapread": qc_data["Mappable reads (reads mapped to human genome)"],
        "xxMapread2": qc_data["Mappable reads % (out of de-duplicated reads)"],
        "xxMapyield": qc_data["Mappable yield (Mbp)"],
        "xxMapmeandepth": qc_data["Mappable mean depth (X)"],
        "xx1xcov": qc_data["% >= 1X coverage"],
        "xx5xcov": qc_data["% >= 5X coverage"],
        "xx10xcov": qc_data["% >= 10X coverage"],
        "xx15xcov": qc_data["% >= 15X coverage"],
        "xx20xcov": qc_data["% >= 20X coverage"],
        "xx30xcov": qc_data["% >= 30X coverage"],
        "xxSnps": qc_data["SNPs"],
        "xxSmallins": qc_data["Small insertions"],
        "xxSmalldel": qc_data["Small deletions"],
        "xxScodvar": qc_data["Synonymous coding variants"],
        "xxNscodvar": qc_data["Non-synonymous coding variants"],
        "xxCopynumgan": qc_data["Copy number gains"],
        "xxCopynumloss": qc_data["Copy number losses"],
        "xxDuplication": qc_data["Duplications"],
        "xxInsert": qc_data["Insertions"],
        "xxDel": qc_data["Deletions"],
        "xxInver": qc_data["Inversions"],
        "xxTrans": qc_data["Translocations"],
        "xxSplicing": qc_data["splicing variants"],
        "xxStgain": qc_data["stop gained"],
        "xxStlost": qc_data["stop lost"],
        "xxShift": qc_data["frame shift"],
        "xxSnp138": qc_data["% found in dbSNP138"],
        "xxSnp142": "0",
        "xxHethom": qc_data["het/hom ratio"],
        "xxTstv": qc_data["Ts/Tv ratio"],
        "xxDoc": qc_data["DOC"],
        "xxMode": qc_data["Mode"],
        "xxIqr": qc_data["IQR"],
        "xxDistance": qc_data["Distance"],
        "xxFreemixAsn": qc_data["ASN_Freemix"],
        "xxFreemixEur": qc_data["EUR_Freemix"],
        "qc_method":"AESPA"
    }
    with open("${meta.id}_input.json", 'w') as f:
        json.dump([payload], f, indent = 4)
    """
}