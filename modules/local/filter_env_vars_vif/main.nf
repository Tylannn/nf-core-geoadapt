process FILTER_ENV_VARS_VIF {
    tag "VIF filtering"
    label 'process_low'

    conda "${moduleDir}/../environment.yml"
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/r-base:4.3.1' :
        'quay.io/biocontainers/r-base:4.3.1' }"

    input:
    path bioclim_csv
    val vif_threshold

    output:
    path "filtered_env_vars.csv", emit: filtered_csv
    path "vif_report.txt"        , emit: vif_report
    path "versions.yml"          , emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def args = task.ext.args ?: ''
    """
    #!/usr/bin/env Rscript

    # Load required libraries
    library(vegan)
    library(dplyr)
    library(readr)

    # Read bioclimatic data
    bioclim_data <- read_csv("${bioclim_csv}")
    
    # Extract environmental variables (exclude population, lat, lon)
    env_vars <- bioclim_data %>%
        select(-population, -latitude, -longitude)
    
    # Remove variables with missing values or zero variance
    env_vars_clean <- env_vars %>%
        select_if(~ !any(is.na(.)) && var(., na.rm = TRUE) > 0)
    
    # Function to calculate VIF iteratively
    filter_by_vif <- function(data, threshold = ${vif_threshold}) {
        vif_results <- data.frame(
            variable = character(),
            vif = numeric(),
            action = character(),
            stringsAsFactors = FALSE
        )
        
        current_data <- data
        iteration <- 1
        
        while(ncol(current_data) > 1) {
            if(ncol(current_data) < 2) break
            
            # Calculate VIF for current variables
            vif_values <- vif(current_data)
            
            # Find maximum VIF
            max_vif <- max(vif_values)
            max_var <- names(vif_values)[which.max(vif_values)]
            
            # Record VIF result
            vif_results <- rbind(vif_results, data.frame(
                variable = max_var,
                vif = max_vif,
                action = ifelse(max_vif > threshold, "removed", "kept"),
                stringsAsFactors = FALSE
            ))
            
            # If max VIF is below threshold, keep all remaining variables
            if(max_vif <= threshold) {
                # Add remaining variables to results
                remaining_vars <- names(current_data)[names(current_data) != max_var]
                for(var in remaining_vars) {
                    if(!var %in% vif_results\$variable) {
                        vif_results <- rbind(vif_results, data.frame(
                            variable = var,
                            vif = vif_values[var],
                            action = "kept",
                            stringsAsFactors = FALSE
                        ))
                    }
                }
                break
            }
            
            # Remove variable with highest VIF
            current_data <- current_data %>% select(-all_of(max_var))
            iteration <- iteration + 1
            
            if(ncol(current_data) == 0) break
        }
        
        return(list(data = current_data, results = vif_results))
    }
    
    # Apply VIF filtering
    vif_filtered <- filter_by_vif(env_vars_clean, ${vif_threshold})
    
    # Combine filtered environmental data with population info
    filtered_data <- bioclim_data %>%
        select(population, latitude, longitude) %>%
        bind_cols(vif_filtered\$data)
    
    # Write filtered data
    write_csv(filtered_data, "filtered_env_vars.csv")
    
    # Write VIF report
    vif_report <- paste0(
        "VIF Filtering Report\\n",
        "===================\\n",
        "Threshold: ", ${vif_threshold}, "\\n",
        "Original variables: ", ncol(env_vars), "\\n",
        "Variables after cleaning: ", ncol(env_vars_clean), "\\n",
        "Variables after VIF filtering: ", ncol(vif_filtered\$data), "\\n\\n",
        "VIF Results:\\n"
    )
    
    vif_table <- paste(
        sprintf("%-15s %10s %10s", "Variable", "VIF", "Action"),
        paste(rep("-", 35), collapse = ""),
        sep = "\\n"
    )
    
    for(i in 1:nrow(vif_filtered\$results)) {
        row <- vif_filtered\$results[i, ]
        vif_table <- paste(vif_table,
            sprintf("%-15s %10.3f %10s", row\$variable, row\$vif, row\$action),
            sep = "\\n"
        )
    }
    
    writeLines(paste(vif_report, vif_table, sep = "\\n"), "vif_report.txt")

    # Create versions file
    writeLines(c(
        '"${task.process}":',
        paste0('    r-base: "', R.version.string, '"'),
        paste0('    r-vegan: "', packageVersion("vegan"), '"')
    ), "versions.yml")
    """

    stub:
    """
    touch filtered_env_vars.csv
    echo "VIF Filtering Report - Stub" > vif_report.txt
    echo '"${task.process}":' > versions.yml
    echo '    r-base: "4.3.1"' >> versions.yml
    """
}