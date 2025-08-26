# nf-core/geoadapt Pipeline Development Instructions

Always reference these instructions first and fallback to search or bash commands only when you encounter unexpected information that does not match the info here.

## Overview
nf-core/geoadapt is a Nextflow bioinformatics pipeline for genomic adaptation analysis. It follows nf-core standards (template version 3.3.1) and requires Nextflow >=24.04.2.

The pipeline analyzes VCF files with population and geographic data to identify genomic signatures of local adaptation using tools like PLINK2 and generates comprehensive reports with MultiQC.

## Quick Start Development Setup

### Prerequisites Installation
Install these dependencies in order. NEVER CANCEL long-running installations:

```bash
# Install Java 17+ (required for Nextflow)
apt-get update && apt-get install -y openjdk-17-jdk

# Install Nextflow (NEVER CANCEL - takes 2-5 minutes)
curl -s https://get.nextflow.io | bash
sudo mv nextflow /usr/local/bin/
chmod +x /usr/local/bin/nextflow
# Alternative if network restricted:
wget -qO nextflow "https://github.com/nextflow-io/nextflow/releases/latest/download/nextflow"
chmod +x nextflow && sudo mv nextflow /usr/local/bin/

# Install nf-core tools (NEVER CANCEL - takes 3-5 minutes)
pip3 install nf-core==3.3.2

# Install Docker (for container execution)
# OR install Singularity/Apptainer as alternative
```

### Repository Setup and Validation
Bootstrap and validate the repository:

```bash
# Clone and navigate to repository
git clone <repository-url>
cd nf-core-geoadapt

# Verify Nextflow installation
nextflow -version
# Expected: Nextflow version 24.04.2 or higher

# Verify nf-core tools
nf-core --version
# Expected: nf-core version 3.3.2

# Verify repository structure
ls -la main.nf nextflow.config nf-test.config
# All files should exist

# Verify key directories exist
ls -la workflows/ modules/ subworkflows/ conf/ docs/
# All directories should be present

# Install pre-commit hooks (takes 2-3 minutes)
pip3 install pre-commit
pre-commit install

# Validate basic JSON/YAML syntax
python3 -c "import json; json.load(open('nextflow_schema.json'))"
python3 -c "import json; json.load(open('modules.json'))"
```

## Building and Testing

### Linting and Code Quality
ALWAYS run these validation steps before committing changes:

```bash
# Run nf-core pipeline linting (NEVER CANCEL - takes 5-15 minutes)
nf-core pipelines lint --dir . --timeout 900
# Use timeout 900+ seconds (15+ minutes) to prevent premature cancellation

# Run pre-commit hooks (NEVER CANCEL - takes 3-10 minutes on first run)
pre-commit run --all-files --timeout 600
# Takes longer on first run due to environment setup

# NOTE: Prettier is run via pre-commit hooks, not directly available
# Check specific files manually if needed:
python3 -c "import json; json.load(open('nextflow_schema.json'))" # Validate JSON
yamllint nextflow.config || echo "yamllint not available - use pre-commit"
```

### Pipeline Testing
Test the pipeline functionality:

```bash
# Quick test with test profile (NEVER CANCEL - takes 10-30 minutes)
nextflow run . -profile test,docker --outdir test_output --timeout 1800
# CRITICAL: Always use docker/singularity profile for reproducible results
# Test profile uses small dataset, expect 10-30 minute runtime

# NOTE: test_full profile currently uses placeholder data from viralrecon
# Full test with test_full dataset (NEVER CANCEL - takes 30 minutes - 2 hours)
nextflow run . -profile test_full,docker --outdir test_full_output --timeout 7200
# test_full profile may use placeholder data; verify input paths in conf/test_full.config

# Run nf-test suite (NEVER CANCEL - takes 15-45 minutes)
# First install nf-test:
wget -qO- get.nf-test.com | bash
./nf-test test tests/default.nf.test --timeout 2700
# Individual tests may take 15-45 minutes

# Test individual modules (faster validation)
./nf-test test modules/nf-core/multiqc/tests/main.nf.test --timeout 900
./nf-test test modules/nf-core/plink2/pca/tests/main.nf.test --timeout 900
```

### Container and Dependency Management
Manage containers and dependencies:

```bash
# Pull required containers (NEVER CANCEL - takes 15-60 minutes)
# This happens automatically on first run, but can be done manually:
docker pull quay.io/nfcore/geoadapt:dev
docker pull quay.io/biocontainers/plink2:2.00a5.10--h4ac6f70_0
docker pull quay.io/biocontainers/multiqc:1.21--pyhdfd78af_0

# For Singularity (NEVER CANCEL - takes 20-90 minutes)
export NXF_SINGULARITY_CACHEDIR=$PWD/singularity_cache
nextflow run . -profile test,singularity --outdir test_output_singularity --timeout 5400
```

## Running the Pipeline

### Basic Execution
Run the pipeline with different configurations:

```bash
# Standard run with Docker (recommended)
nextflow run nf-core/geoadapt \
    --input samplesheet.csv \
    --outdir results \
    -profile docker

# With Singularity (for HPC environments)
nextflow run nf-core/geoadapt \
    --input samplesheet.csv \
    --outdir results \
    -profile singularity

# Resume failed runs
nextflow run nf-core/geoadapt \
    --input samplesheet.csv \
    --outdir results \
    -profile docker \
    -resume
```

### Input Data Preparation
Prepare samplesheet correctly:

The pipeline expects a CSV file with the following columns:
- `sample`: Sample identifier
- `vcf_path`: Path to VCF file (must be gzipped)
- `population`: Population identifier
- `latitude`: Geographic latitude
- `longitude`: Geographic longitude

Example `samplesheet.csv`:
```csv
sample,vcf_path,population,latitude,longitude
sample1,data/sample1.vcf.gz,pop1,52.486243,-1.890401
sample2,data/sample2.vcf.gz,pop1,60.17,24.93
sample3,data/sample3.vcf.gz,pop2,23.13333,113.266667
```

## Validation and Testing Scenarios

### Manual Validation Steps
ALWAYS run these scenarios after making changes:

1. **Basic Pipeline Validation**:
   ```bash
   # Test with minimal dataset (NEVER CANCEL - 10-30 minutes)
   nextflow run . -profile test,docker --outdir validation_test --timeout 1800
   
   # Verify expected outputs exist:
   ls -la validation_test/
   # Should contain: pipeline_info/, multiqc_report.html, results directories
   ```

2. **Complete Workflow Testing**:
   ```bash
   # Run full test scenario (NEVER CANCEL - 30 minutes - 2 hours)
   # NOTE: test_full currently uses viralrecon placeholder data
   nextflow run . -profile test_full,docker --outdir full_validation --timeout 7200
   
   # Check MultiQC report generation
   open full_validation/multiqc_report.html
   # Should display comprehensive QC metrics and plots
   
   # Verify expected modules were run
   ls -la full_validation/pipeline_info/
   # Should contain: execution reports, software versions, etc.
   ```

3. **Multi-profile Testing**:
   ```bash
   # Test different container engines (each takes 15-45 minutes)
   nextflow run . -profile test,docker --outdir test_docker --timeout 2700
   nextflow run . -profile test,singularity --outdir test_singularity --timeout 2700
   
   # Compare outputs should be identical
   diff -r test_docker/pipeline_info/ test_singularity/pipeline_info/
   ```

### Development Workflow Validation
After making code changes:

```bash
# 1. Run linting first (5-15 minutes)
nf-core pipelines lint --timeout 900

# 2. Run basic tests (10-30 minutes)
nextflow run . -profile test,docker --outdir dev_test --timeout 1800

# 3. Run specific module tests if modified
./nf-test test modules/nf-core/plink2/pca/tests/main.nf.test --timeout 1800

# 4. Verify MultiQC integration
grep -r "geoadapt" dev_test/multiqc_report.html
# Should contain pipeline-specific content
```

## Key File Locations

### Core Pipeline Files
- `main.nf` - Main workflow entry point
- `nextflow.config` - Main configuration file
- `workflows/geoadapt.nf` - Primary workflow definition
- `conf/` - Configuration profiles (base, test, etc.)

### Testing and Validation
- `tests/default.nf.test` - Main pipeline test
- `nf-test.config` - nf-test configuration
- `.nf-core.yml` - nf-core pipeline configuration
- `.pre-commit-config.yaml` - Pre-commit hook configuration

### Documentation and Assets
- `docs/usage.md` - Detailed usage documentation
- `docs/output.md` - Output description
- `assets/samplesheet.csv` - Example input data
- `assets/multiqc_config.yml` - MultiQC configuration

### Modules and Subworkflows
- `modules/nf-core/` - Standard nf-core modules (PLINK2, MultiQC)
- `subworkflows/local/` - Pipeline-specific subworkflows
- `subworkflows/nf-core/` - Standard nf-core subworkflows

## Common Development Tasks

### Adding New Parameters
1. Edit `nextflow_schema.json` to define the parameter
2. Add default value in `nextflow.config`
3. Update `docs/usage.md` with parameter description
4. Test parameter validation:
   ```bash
   nextflow run . --help
   nextflow run . -profile test,docker --new_parameter value --timeout 1800
   ```

### Adding New Modules
1. Search nf-core modules:
   ```bash
   nf-core modules list remote
   ```
2. Install module:
   ```bash
   nf-core modules install <module_name>
   ```
3. Add to workflow in `workflows/geoadapt.nf`
4. Test integration:
   ```bash
   ./nf-test test modules/nf-core/<module_name>/tests/main.nf.test --timeout 1800
   ```

### Updating Documentation
1. Modify relevant files in `docs/`
2. Update `README.md` if needed
3. Validate documentation links:
   ```bash
   markdown-link-check README.md docs/*.md
   ```

## Troubleshooting

### Common Issues
1. **Nextflow not found**: Ensure `/usr/local/bin` is in `$PATH`
2. **Container pull failures**: Check Docker daemon status and network connectivity
3. **Test timeouts**: Always use appropriate timeout values (15+ minutes for basic tests)
4. **Memory issues**: Increase `nextflow.config` memory settings for resource-intensive processes
5. **Network connectivity issues**: 
   - Nextflow dependencies download failure: Manually download required JAR files
   - nf-core registry access failure: Use local pipeline directory instead of remote
   - Container pull failures: Use cached containers or singularity images
   - Pre-commit hook failures: Skip hooks that require internet access for initial setup

### Network-Restricted Environments
If working in environments with limited internet access:

```bash
# Use local pipeline execution instead of remote
nextflow run /path/to/local/pipeline -profile test,docker

# Skip problematic pre-commit hooks initially
SKIP=prettier pre-commit run --all-files

# Use cached/local containers
export NXF_SINGULARITY_CACHEDIR=/shared/containers
# or pre-pulled Docker images

# Validate basic pipeline structure without external dependencies
ls -la main.nf workflows/ modules/ # Basic structure check
python3 -c "import json; json.load(open('nextflow_schema.json'))" # JSON validation
```

### Performance Optimization
- Use `--max_cpus`, `--max_memory`, `--max_time` parameters to limit resource usage
- Enable `conda.useMamba = true` for faster dependency resolution
- Use local Nextflow tower for monitoring long-running workflows

### Debugging Failed Runs
```bash
# Check Nextflow log
cat .nextflow.log

# Check work directory for failed processes
ls -la work/

# Re-run with debug information
nextflow run . -profile test,docker --outdir debug_test -with-trace -with-dag dag.html --timeout 1800
```

## CI/CD Integration

The pipeline uses GitHub Actions for continuous integration:
- `.github/workflows/linting.yml` - Code quality checks
- `.github/workflows/nf-test.yml` - Pipeline testing  
- `.github/workflows/awstest.yml` - AWS cloud testing
- `.github/workflows/awsfulltest.yml` - AWS full-scale testing
- `.github/workflows/branch.yml` - Branch-specific checks

All workflows include proper timeout configurations and resource limits.

## Performance Expectations

### Timing Guidelines
- **Initial setup**: 10-15 minutes (tool installation)
- **Container pulls**: 15-60 minutes (first time)
- **Lint checks**: 5-15 minutes
- **Pre-commit hooks**: 3-10 minutes (first run), 30 seconds-2 minutes (subsequent)
- **Basic repository validation**: 10-30 seconds  
- **Test profile run**: 10-30 minutes
- **Test_full profile run**: 30 minutes-2 hours (placeholder data)
- **nf-test individual modules**: 5-15 minutes each
- **nf-test full suite**: 15-45 minutes
- **Docker container download**: 2-15 minutes per container
- **Singularity image conversion**: 5-30 minutes per image

### Resource Requirements
- **Minimum**: 4 CPUs, 8GB RAM for test profile
- **Recommended**: 8+ CPUs, 16+ GB RAM for full testing
- **Storage**: 50GB+ for containers and test data

**CRITICAL: Always set appropriate timeouts for all commands. NEVER CANCEL builds or tests prematurely.**