workflow DEMUX_CHECK {
    take:
    ch_api_response
    
    main:
    confirm_check(ch_samplesheet)
}

process confirm_check {
    tag "Demux confirm for ${meta.id}"

    input:
    tuple val(meta), path(fastq_1), path(fastq_2)
    path(project_path)

    output:
    tuple val(meta), path("${meta.id}_1.fastq.gz"), path("${meta.id}_2.fastq.gz"), emit:ch_confirmed_samplesheet

    script:

    """
    #!/usr/bin/env python3
    import os
    import csv
    import time
    from glob import glob

    def check_confirm_file(project_path):
        confirm_pattern = f"${project_path}/${meta.order}/*/*${meta.fc_id}*/confirm.txt"
        flag = 0
        while True: #wait until 60 days
            flag += 1
            confirm_file = glob(confirm_pattern)
            if len(confirm_file) >= 1:
                for confirm_file in glob(confirm_pattern):
                    with open(confirm_file, 'r') as f:
                        reader = csv.DictReader(f, delimiter = '\t')
                        for row in reader:
                            if (row['SampleID'] == '${meta.sample}' and row['region'] == '${meta.lane}':
                                pass_filter = row['Result']
                                if pass_filter == 'PASS':
                                    return True
                                elif flag >= 60*24*60 or pass_filter != 'PASS':
                                    return False
                                else:
                                    print(f"${meta.id} is out of control; please look at the {confirm_pattern}")
                                    sys.exit(1)
                            else:
                                continue
            else:
                time.sleep(60)

    project_path = "${project_path}"
    fastq_1 = "${fastq_1}"
    fastq_2 = "${fastq_2}"

    if check_confirm_file(project_path):
        os.symlink(os.path.abspath(fastq_1), f"${meta.id}_1.fastq.gz")
        os.symlink(os.path.abspath(fastq_2), f"${meta.id}_2.fastq.gz")
        print(f"Created symlinks for {meta['sample']}")
    else:
        print(f"No PASS result found for {meta['sample']}")
        sys.exit(0)
    """
}