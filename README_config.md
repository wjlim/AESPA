# AESPA Pipeline Configuration Documentation

## 1. Main Configuration (nextflow.config)

### Core Parameters
```groovy
params {
    ref_conf = "${baseDir}/conf/reference.json"
    max_memory = 210.GB
    max_cpus = 32
    max_time = 240.h
    conda_env_path = "/mmfs1/lustre2/BI_Analysis/bi2/anaconda3"
}
```

### Pipeline-Specific Parameters
```groovy
params {
    // Analysis Parameters
    aligner = 'iSAAC'        // Choice between 'iSAAC' or 'bwa'
    merge_flag = false       // Controls merge mode
    merge = false           // Controls cross-plate merging
    
    // QC Parameters
    target_x = 5            // Target coverage for subsampling
    sub_limit = 0.6         // Subsampling threshold
    freemix_limit = 0.05    // Contamination threshold
    mapping_rate_limit = 88  // Minimum mapping rate
    deduplicate_rate_limit = 78  // Minimum deduplication rate
}
```

### HPC Optimization
A key feature for HPC environments is the offline mode configuration:
```groovy
env {
    NXF_OFFLINE = true
    CONDA_PREFIX = params.conda_env_path
}
```

## 2. Base Resource Configuration (base.config)

### Process Resource Labels
```groovy
process {
    // Default resources
    cpus   = { check_max( 1    * task.attempt, 'cpus'   ) }
    memory = { check_max( 6.GB * task.attempt, 'memory' ) }
    time   = { check_max( 240.h  * task.attempt, 'time'   ) }

    // Process-specific labels
    withLabel:process_single {
        cpus   = { check_max( 1                  , 'cpus'    ) }
        memory = { check_max( 9.GB * task.attempt, 'memory'  ) }
    }
    withLabel:process_high {
        cpus   = { check_max( 16    * task.attempt, 'cpus'    ) }
        memory = { check_max( 105.GB * task.attempt, 'memory'  ) }
    }
}
```

## 3. Module Output Configuration (modules.config)

### Directory Structure
```groovy
params {
    bam_stats_dir = { meta -> "${params.outdir}/${meta.sample}/${params.prefix}/${meta.fc_id}.${meta.lane}.bam_stats" }
    vcf_dir = { meta -> "${params.outdir}/${meta.sample}/${params.prefix}/${meta.fc_id}.${meta.lane}.VCF" }
    api_dir = { meta -> "${params.outdir}/${meta.sample}/${params.prefix}/API_CALL" }
}
```

### Publishing Rules
```groovy
process {
    withName: 'calc_distance|calc_DOC|calc_genome_coverage' {
        publishDir = [
            path: { params.bam_stats_dir(meta) },
            mode: 'copy'
        ]
    }
}
```

## 4. HPC Optimization Strategy

### Offline Mode Benefits
The pipeline implements an offline-first approach for HPC environments:

1. **Pre-configured Environments**
```groovy
process some_process {
    conda NXF_OFFLINE == 'true' ?
        "${params.conda_env_path}/envs/env_name":
        "${baseDir}/conf/env.yml"
}
```

2. **Performance Advantages**
- Eliminates conda environment creation overhead
- Reduces network dependencies
- Speeds up pipeline initialization

### Pre-Installation Strategy
For optimal performance, pre-install all required conda environments:

```bash
# Pre-installation script example
for yml in conf/*.yml; do
    env_name=$(basename $yml .yml)
    conda env create -f $yml -n $env_name
done
```

### Environment Management
The pipeline intelligently manages conda environments:
- Uses pre-installed environments when NXF_OFFLINE=true
- Falls back to environment.yml when offline mode is disabled
- Significantly reduces startup time in production environments

### Best Practices for HPC Deployment
1. **Pre-Installation**
   - Install all conda environments before pipeline deployment
   - Verify environment accessibility from compute nodes

2. **Environment Location**
   - Store environments in a shared, high-performance filesystem
   - Ensure read access from all compute nodes

3. **Configuration**
   - Set NXF_OFFLINE=true in production
   - Configure conda_env_path to point to pre-installed environments

4. **Performance Impact**
   - Eliminates ~5-10 minutes of environment setup per job
   - Reduces network load on cluster
   - Improves pipeline reliability

### Example Performance Gains
```
Standard Mode:
Environment setup: 5-10 minutes per job
Network dependency: High
Reliability: Dependent on network

Offline Mode with Pre-installed Environments:
Environment setup: < 1 second
Network dependency: None
Reliability: High
```

This optimization strategy is particularly effective in large-scale production environments where multiple jobs are running simultaneously. 