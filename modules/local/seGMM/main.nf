process SEGMM {
    label 'process_medium'
    
    conda (params.enable_conda ? "environment.yml" : null)
    
    input:
        path vcf
        path bam_list
        path ref_fasta
        val genome_version
        val seq_type
        val chromosome
        val sry
        path ref_additional
        val uncertain_threshold
        val num_threads
        val quality_threshold
        val alignment_format

    output:
        path "*", emit: results

    script:
        def ref_param = ref_fasta ? "-R ${ref_fasta}" : ""
        def chr_param = chromosome ? "-c ${chromosome}" : ""
        def sry_param = sry ? "-s ${sry}" : ""
        def ref_add_param = ref_additional ? "-r ${ref_additional}" : ""
        def uncert_param = uncertain_threshold ? "-u ${uncertain_threshold}" : ""
        def thread_param = num_threads ? "-n ${num_threads}" : ""
        def qual_param = quality_threshold ? "-q ${quality_threshold}" : ""
        
        """
        # Clone seGMM repository
        git clone https://github.com/liusihan/seGMM.git
        cd seGMM
        chmod +x seGMM.py
        
        # Run seGMM
        ./seGMM.py \\
            -vcf ${vcf} \\
            -i ${bam_list} \\
            -a ${alignment_format} \\
            ${ref_param} \\
            -g ${genome_version} \\
            -t ${seq_type} \\
            ${chr_param} \\
            ${sry_param} \\
            ${ref_add_param} \\
            ${uncert_param} \\
            ${thread_param} \\
            ${qual_param} \\
            -o .
        """
} 