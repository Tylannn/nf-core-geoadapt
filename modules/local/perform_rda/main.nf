process PERFORM_RDA {
    tag "RDA analysis"
    label 'process_medium'

    conda "${moduleDir}/../environment.yml"
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/r-base:4.3.1' :
        'quay.io/biocontainers/r-base:4.3.1' }"

    input:
    tuple val(meta), path(eigenvec)
    path filtered_env_csv
    path samplesheet

    output:
    path "rda_results.txt"    , emit: results
    path "rda_plot.pdf"       , emit: plot
    path "rda_summary.csv"    , emit: summary
    path "versions.yml"       , emit: versions

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
    library(ggplot2)

    # Read input data
    pca_data <- read.table("${eigenvec}", header = FALSE)
    env_data <- read_csv("${filtered_env_csv}")
    samplesheet <- read_csv("${samplesheet}")
    
    # Prepare PCA data (remove first two columns - FID and IID)
    pca_matrix <- as.matrix(pca_data[, -(1:2)])
    colnames(pca_matrix) <- paste0("PC", 1:ncol(pca_matrix))
    
    # Ensure sample order matches
    sample_ids <- pca_data[, 2]  # IID column
    
    # Match environmental data to samples by population
    # Create a mapping from sample to population
    sample_pop_map <- samplesheet %>%
        select(sample, population) %>%
        distinct()
    
    # Map samples to populations and then to environmental data
    sample_env_data <- data.frame(sample = sample_ids) %>%
        left_join(sample_pop_map, by = "sample") %>%
        left_join(env_data, by = "population")
    
    # Extract environmental variables (exclude non-environmental columns)
    env_vars <- sample_env_data %>%
        select(-sample, -population, -latitude, -longitude)
    
    # Remove any rows with missing environmental data
    complete_cases <- complete.cases(env_vars)
    pca_matrix_clean <- pca_matrix[complete_cases, ]
    env_vars_clean <- env_vars[complete_cases, ]
    sample_info_clean <- sample_env_data[complete_cases, ]
    
    # Perform partial RDA
    # Use first few PCs as covariates to control for population structure
    n_cov_pcs <- min(5, ncol(pca_matrix_clean) - 1)  # Use up to 5 PCs as covariates
    cov_pcs <- pca_matrix_clean[, 1:n_cov_pcs, drop = FALSE]
    response_pcs <- pca_matrix_clean[, (n_cov_pcs + 1):ncol(pca_matrix_clean), drop = FALSE]
    
    # Perform RDA
    rda_result <- rda(response_pcs ~ . + Condition(cov_pcs), data = env_vars_clean)
    
    # Extract results
    rda_summary <- summary(rda_result)
    
    # Perform significance tests
    rda_anova <- anova(rda_result, permutations = 999)
    rda_anova_by_term <- anova(rda_result, by = "terms", permutations = 999)
    rda_anova_by_axis <- anova(rda_result, by = "axis", permutations = 999)
    
    # Write detailed results
    results_text <- capture.output({
        cat("REDUNDANCY ANALYSIS (RDA) RESULTS\\n")
        cat("================================\\n\\n")
        
        cat("Model Summary:\\n")
        print(rda_result)
        cat("\\n")
        
        cat("Variance Explained:\\n")
        print(rda_summary\$cont\$importance)
        cat("\\n")
        
        cat("Overall Model Significance:\\n")
        print(rda_anova)
        cat("\\n")
        
        cat("Significance by Environmental Term:\\n")
        print(rda_anova_by_term)
        cat("\\n")
        
        cat("Significance by RDA Axis:\\n")
        print(rda_anova_by_axis)
        cat("\\n")
        
        cat("Environmental Variable Scores:\\n")
        print(rda_summary\$biplot)
        cat("\\n")
        
        cat("Site Scores (first 10):\\n")
        print(head(rda_summary\$sites, 10))
    })
    
    writeLines(results_text, "rda_results.txt")
    
    # Create summary CSV
    summary_df <- data.frame(
        metric = c("Total_variance", "Constrained_variance", "Unconstrained_variance", 
                  "Proportion_constrained", "Overall_F", "Overall_p_value",
                  "Number_env_variables", "Number_samples"),
        value = c(
            rda_summary\$tot.chi,
            rda_summary\$constr.chi, 
            rda_summary\$unconstr.chi,
            rda_summary\$constr.chi / rda_summary\$tot.chi,
            rda_anova\$F[1],
            rda_anova[1, "Pr(>F)"],
            ncol(env_vars_clean),
            nrow(env_vars_clean)
        )
    )
    
    write_csv(summary_df, "rda_summary.csv")
    
    # Create RDA plot
    pdf("rda_plot.pdf", width = 10, height = 8)
    
    # Biplot
    plot(rda_result, type = "n", main = "RDA Biplot")
    points(rda_result, display = "sites", pch = 16, col = "blue", cex = 0.8)
    text(rda_result, display = "bp", col = "red", cex = 0.8)
    
    # Add population colors if available
    if("population" %in% colnames(sample_info_clean)) {
        pop_colors <- rainbow(length(unique(sample_info_clean\$population)))
        names(pop_colors) <- unique(sample_info_clean\$population)
        
        # Replot with population colors
        plot(rda_result, type = "n", main = "RDA Biplot by Population")
        points(rda_result, display = "sites", 
               pch = 16, 
               col = pop_colors[sample_info_clean\$population], 
               cex = 0.8)
        text(rda_result, display = "bp", col = "red", cex = 0.8)
        legend("topright", 
               legend = names(pop_colors),
               col = pop_colors,
               pch = 16,
               title = "Population")
    }
    
    dev.off()

    # Create versions file
    writeLines(c(
        '"${task.process}":',
        paste0('    r-base: "', R.version.string, '"'),
        paste0('    r-vegan: "', packageVersion("vegan"), '"'),
        paste0('    r-ggplot2: "', packageVersion("ggplot2"), '"')
    ), "versions.yml")
    """

    stub:
    """
    echo "RDA Results - Stub" > rda_results.txt
    touch rda_plot.pdf
    echo "metric,value" > rda_summary.csv
    echo "stub,1" >> rda_summary.csv
    echo '"${task.process}":' > versions.yml
    echo '    r-base: "4.3.1"' >> versions.yml
    """
}