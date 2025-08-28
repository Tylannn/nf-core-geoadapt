/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    IMPORT MODULES / SUBWORKFLOWS / FUNCTIONS
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/
include { MULTIQC                } from '../modules/nf-core/multiqc/main'
include { PLINK2_PCA             } from '../modules/nf-core/plink2/pca/main'
include { PLINK2_VCF             } from '../modules/nf-core/plink2/vcf/main'
include { RDA_ANALYSIS           } from '../subworkflows/local/rda_analysis/main'
include { paramsSummaryMap       } from 'plugin/nf-schema'
include { paramsSummaryMultiqc   } from '../subworkflows/nf-core/utils_nfcore_pipeline'
include { softwareVersionsToYAML } from '../subworkflows/nf-core/utils_nfcore_pipeline'
include { methodsDescriptionText } from '../subworkflows/local/utils_nfcore_geoadapt_pipeline'

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    RUN MAIN WORKFLOW
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

workflow GEOADAPT {

    take:
    ch_samplesheet // channel: samplesheet read in from --input
    main:

    ch_versions = Channel.empty()
    ch_multiqc_files = Channel.empty()

    //
    // Create channel of unique VCF files for joint population analysis
    // In population genetics, joint analysis of all samples is preferred over individual analysis
    //
    ch_vcf = ch_samplesheet
        .map { meta, vcf_path -> [vcf_path, meta] }
        .unique { it[0] }  // Get unique VCF files
        .map { vcf_path, _meta -> 
            def joint_meta = [
                id: "joint",
                vcf_path: vcf_path
            ]
            [joint_meta, file(vcf_path)]
        }

    //
    // MODULE: Convert VCF to PLINK binary format
    // Process unique VCF files to create PLINK binary format for efficient analysis
    //
    PLINK2_VCF (
        ch_vcf
    )
    ch_versions = ch_versions.mix(PLINK2_VCF.out.versions)

    //
    // MODULE: Principal Component Analysis for population structure
    // Joint PCA analysis of all samples to identify population structure and genomic adaptation patterns
    //
    PLINK2_PCA (
        PLINK2_VCF.out.plink
            .map { meta, pgen, psam, pvar ->
                [
                    meta,
                    params.pca_npcs ?: 10,       // Number of principal components to calculate
                    params.pca_approx ?: false,  // Whether to use approximation algorithm
                    pgen,                        // PLINK binary genotype file
                    psam,                        // PLINK sample information file  
                    pvar                         // PLINK variant information file
                ]
            }
    )
    ch_versions = ch_versions.mix(PLINK2_PCA.out.versions)

    //
    // SUBWORKFLOW: RDA Analysis (optional)
    // Perform Redundancy Analysis if enabled
    //
    if (params.rda) {
        RDA_ANALYSIS (
            ch_samplesheet,
            PLINK2_PCA.out.evecfile,
            params.vif_threshold
        )
        ch_versions = ch_versions.mix(RDA_ANALYSIS.out.versions)
    }

    //
    // Collate and save software versions
    //
    softwareVersionsToYAML(ch_versions)
        .collectFile(
            storeDir: "${params.outdir}/pipeline_info",
            name: 'nf_core_geoadapt_software_mqc_versions.yml',
            sort: true,
            newLine: true
        ).set { ch_collated_versions }


    //
    // MODULE: MultiQC - Generate comprehensive quality control report
    //
    ch_multiqc_config        = Channel.fromPath(
        "$projectDir/assets/multiqc_config.yml", checkIfExists: true)
    ch_multiqc_custom_config = params.multiqc_config ?
        Channel.fromPath(params.multiqc_config, checkIfExists: true) :
        Channel.empty()
    ch_multiqc_logo          = params.multiqc_logo ?
        Channel.fromPath(params.multiqc_logo, checkIfExists: true) :
        Channel.empty()

    summary_params      = paramsSummaryMap(
        workflow, parameters_schema: "nextflow_schema.json")
    ch_workflow_summary = Channel.value(paramsSummaryMultiqc(summary_params))
    ch_multiqc_files = ch_multiqc_files.mix(
        ch_workflow_summary.collectFile(name: 'workflow_summary_mqc.yaml'))
    ch_multiqc_custom_methods_description = params.multiqc_methods_description ?
        file(params.multiqc_methods_description, checkIfExists: true) :
        file("$projectDir/assets/methods_description_template.yml", checkIfExists: true)
    ch_methods_description                = Channel.value(
        methodsDescriptionText(ch_multiqc_custom_methods_description))

    ch_multiqc_files = ch_multiqc_files.mix(ch_collated_versions)
    ch_multiqc_files = ch_multiqc_files.mix(
        ch_methods_description.collectFile(
            name: 'methods_description_mqc.yaml',
            sort: true
        )
    )

    MULTIQC (
        ch_multiqc_files.collect(),
        ch_multiqc_config.toList(),
        ch_multiqc_custom_config.toList(),
        ch_multiqc_logo.toList(),
        [],
        []
    )

    emit:
    multiqc_report = MULTIQC.out.report.toList() // channel: /path/to/multiqc_report.html
    versions       = ch_versions                 // channel: [ path(versions.yml) ]
    pca_eigenvec   = PLINK2_PCA.out.evecfile     // channel: [ meta, eigenvec ]
    pca_eigenval   = PLINK2_PCA.out.evfile       // channel: [ meta, eigenval ]
    pca_log        = PLINK2_PCA.out.logfile      // channel: [ meta, log ]
    
    // RDA outputs (conditional)
    rda_results    = params.rda ? RDA_ANALYSIS.out.rda_results : Channel.empty()    // channel: path(rda_results.txt)
    rda_plot       = params.rda ? RDA_ANALYSIS.out.rda_plot : Channel.empty()       // channel: path(rda_plot.pdf)
    rda_summary    = params.rda ? RDA_ANALYSIS.out.rda_summary : Channel.empty()    // channel: path(rda_summary.csv)
    bioclim_csv    = params.rda ? RDA_ANALYSIS.out.bioclim_csv : Channel.empty()    // channel: path(bioclim_data.csv)
    filtered_csv   = params.rda ? RDA_ANALYSIS.out.filtered_csv : Channel.empty()   // channel: path(filtered_env_vars.csv)
    raster_files   = params.rda ? RDA_ANALYSIS.out.raster_files : Channel.empty()   // channel: path(*.tif)
    vif_report     = params.rda ? RDA_ANALYSIS.out.vif_report : Channel.empty()     // channel: path(vif_report.txt)

}

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    THE END
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/
