process GET_BIOCLIM_DATA {
    tag "Bioclimatic data"
    label 'process_medium'

    conda "${moduleDir}/../environment.yml"
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/r-base:4.3.1' :
        'quay.io/biocontainers/r-base:4.3.1' }"

    input:
    path samplesheet

    output:
    path "bioclim_data.csv"      , emit: bioclim_csv
    path "bioclim_rasters/*.tif" , emit: raster_files
    path "versions.yml"          , emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def args = task.ext.args ?: ''
    """
    #!/usr/bin/env Rscript

    # Load required libraries
    library(geodata)
    library(terra)
    library(dplyr)
    library(readr)

    # Read sample coordinates
    samplesheet <- read_csv("${samplesheet}")
    
    # Create output directory for rasters
    dir.create("bioclim_rasters", showWarnings = FALSE)

    # Get unique population coordinates
    pop_coords <- samplesheet %>%
        group_by(population) %>%
        summarise(
            latitude = first(latitude),
            longitude = first(longitude),
            .groups = 'drop'
        )

    # Get extent for all coordinates with buffer
    lat_range <- range(pop_coords\$latitude)
    lon_range <- range(pop_coords\$longitude)
    
    # Add buffer (approximately 1 degree)
    buffer <- 1
    extent_coords <- c(
        lon_range[1] - buffer, lon_range[2] + buffer,
        lat_range[1] - buffer, lat_range[2] + buffer
    )

    # Download worldclim bioclimatic variables
    bioclim <- worldclim_global(var = "bio", res = 10, path = "bioclim_rasters")
    
    # Crop to study area
    study_extent <- ext(extent_coords)
    bioclim_cropped <- crop(bioclim, study_extent)
    
    # Extract values for each population
    pop_coords_vect <- vect(pop_coords, geom = c("longitude", "latitude"), crs = "EPSG:4326")
    bioclim_values <- extract(bioclim_cropped, pop_coords_vect)
    
    # Combine with population info
    bioclim_data <- cbind(pop_coords, bioclim_values[, -1])  # Remove ID column
    
    # Write output
    write_csv(bioclim_data, "bioclim_data.csv")
    
    # Save individual raster files with standardized names
    for(i in 1:nlyr(bioclim_cropped)) {
        writeRaster(bioclim_cropped[[i]], 
                   filename = paste0("bioclim_rasters/bio", sprintf("%02d", i), ".tif"),
                   overwrite = TRUE)
    }

    # Create versions file
    writeLines(c(
        '"${task.process}":',
        paste0('    r-base: "', R.version.string, '"'),
        paste0('    r-geodata: "', packageVersion("geodata"), '"'),
        paste0('    r-terra: "', packageVersion("terra"), '"')
    ), "versions.yml")
    """

    stub:
    """
    mkdir -p bioclim_rasters
    touch bioclim_data.csv
    touch bioclim_rasters/bio01.tif
    echo '"${task.process}":' > versions.yml
    echo '    r-base: "4.3.1"' >> versions.yml
    """
}