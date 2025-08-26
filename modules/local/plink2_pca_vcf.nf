process PLINK2_PCA_VCF {
    tag "$meta.id"
    label 'process_single'

    conda "bioconda::plink2=2.00a5.10"
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/plink2:2.00a5.10--h4ac6f70_0' :
        'biocontainers/plink2:2.00a5.10--h4ac6f70_0' }"

    input:
    tuple val(meta), path(vcf)
    val npcs
    val use_approx

    output:
    tuple val(meta), path("*.eigenvec"), emit: eigenvec
    tuple val(meta), path("*.eigenval"), emit: eigenval
    tuple val(meta), path("*.log"),      emit: log
    path "versions.yml",                 emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def args = task.ext.args ?: ''
    def prefix = task.ext.prefix ?: "${meta.id}"
    def approx_option = use_approx ? "approx" : ""
    def n_pcs = npcs ?: 10
    """
    plink2 \\
        --vcf ${vcf} \\
        --pca ${n_pcs} ${approx_option} \\
        --memory ${task.memory.toMega()} \\
        $args \\
        --threads $task.cpus \\
        --out ${prefix}

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        plink2: \$(plink2 --version 2>&1 | sed 's/^PLINK v//; s/ 64.*\$//')
    END_VERSIONS
    """

    stub:
    def prefix = task.ext.prefix ?: "${meta.id}"
    """
    touch ${prefix}.eigenvec ${prefix}.eigenval ${prefix}.log

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        plink2: \$(plink2 --version 2>&1 | sed 's/^PLINK v//; s/ 64.*\$//')
    END_VERSIONS
    """
}