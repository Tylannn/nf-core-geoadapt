/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    IMPORT MODULES / SUBWORKFLOWS / FUNCTIONS
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

include { GET_BIOCLIM_DATA      } from '../../modules/local/get_bioclim_data/main'
include { FILTER_ENV_VARS_VIF   } from '../../modules/local/filter_env_vars_vif/main'
include { PERFORM_RDA           } from '../../modules/local/perform_rda/main'

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    RUN SUBWORKFLOW
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

workflow RDA_ANALYSIS {

    take:
    ch_samplesheet    // channel: path(samplesheet.csv)
    ch_pca_eigenvec   // channel: [meta, eigenvec]
    vif_threshold     // val: VIF threshold for filtering

    main:

    ch_versions = Channel.empty()

    //
    // MODULE: Get bioclimatic data based on sample coordinates
    //
    GET_BIOCLIM_DATA (
        ch_samplesheet
    )
    ch_versions = ch_versions.mix(GET_BIOCLIM_DATA.out.versions)

    //
    // MODULE: Filter environmental variables using VIF analysis
    //
    FILTER_ENV_VARS_VIF (
        GET_BIOCLIM_DATA.out.bioclim_csv,
        vif_threshold
    )
    ch_versions = ch_versions.mix(FILTER_ENV_VARS_VIF.out.versions)

    //
    // MODULE: Perform RDA analysis
    //
    PERFORM_RDA (
        ch_pca_eigenvec,
        FILTER_ENV_VARS_VIF.out.filtered_csv,
        ch_samplesheet
    )
    ch_versions = ch_versions.mix(PERFORM_RDA.out.versions)

    emit:
    bioclim_csv    = GET_BIOCLIM_DATA.out.bioclim_csv      // channel: path(bioclim_data.csv)
    raster_files   = GET_BIOCLIM_DATA.out.raster_files     // channel: path(*.tif)
    filtered_csv   = FILTER_ENV_VARS_VIF.out.filtered_csv  // channel: path(filtered_env_vars.csv)
    vif_report     = FILTER_ENV_VARS_VIF.out.vif_report    // channel: path(vif_report.txt)
    rda_results    = PERFORM_RDA.out.results               // channel: path(rda_results.txt)
    rda_plot       = PERFORM_RDA.out.plot                  // channel: path(rda_plot.pdf)
    rda_summary    = PERFORM_RDA.out.summary               // channel: path(rda_summary.csv)
    versions       = ch_versions                           // channel: path(versions.yml)

}

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    THE END
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/