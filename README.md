Core SNP Phylogenomics
======================

The Core SNP phylogenomics pipeline provides a pipeline for identifying high-quality core SNPs among a set of bacterial isolates and generating phylogenetic trees from these SNPs.  The pipeline takes as input a reference genome (in FASTA format) and a set of DNA sequencing reads (in FASTQ format) and proceeds through a number of different stages to find core SNPs.

Authors
-------

The Core SNP Pipeline was developed by the following individuals:  Aaron Petkau, Gary Van Domselaar, Philip Mabon, and Lee Katz.

Tutorial
--------

For a step-by-step tutorial on how to run the core SNP pipeline with some example data, please see https://github.com/apetkau/microbial-informatics-2014/tree/master/labs/core-snp.  A description of the data used for this tutorial as well as a virtual machine to run all the necessary software can be found at https://github.com/apetkau/microbial-informatics-2014/.

An additional tutorial which uses simulated data can be found at https://github.com/apetkau/core-phylogenomics-tutorial.

Quick Start
-----------

### Command ###

If you have a set of DNA sequencing reads, __fastq_reads/*.fastq__, and a reference file containing the DNA sequence of the genome to use for reference mapping, __reference.fasta__, then the following command can be used to generate a core SNP phylogeny.

	snp_phylogenomics_control --mode mapping --input-dir fastq_reads/ --output pipeline_out --reference reference.fasta

### Output ###

Once the pipeline is finished main output files you will want to look at include:

* __pipeline_out/pseudoalign/pseudoalign-positions.tsv__: A tab-separated file containing all variants identified and the positions of each variant on the reference genome.

Example:

	#Chromosome	Position	Status	Reference	isolate1	isolate2
	contig1	20	valid	A	A	T
	contig2	30	filtered-coverage	A	-	A

* __pipeline_out/pseudoalign/matrix.csv__:  A tab-separated file containing a matrix of high-quality SNP distances between isolates.

Example:

	strain	isolate1	isolate2
	isolate1	0	5
	isolate2	5	0

* __pipeline_out/pseudoalign/pseudoalign.phy__: An alignment of variants for each input isolate in phylip format.
* __pipeline_out/phylogeny/pseudoalign.phy_phyml_tree.txt__:  A phylogenetic tree of the above alignment file generated using [PhyML](http://code.google.com/p/phyml/).

### Alternative Commands ###

In addition, if you have a pre-defined set of positions on the reference genome you wish to exclude (repetitive regions, etc) in a tab-separated values file format (see detailed documentation below for a description of the file format) you can run the pipeline with the command:

	snp_phylogenomics_control --mode mapping --input-dir fastq_reads/ --invalid-pos bad_positions.tsv --output pipeline_out --reference reference.fasta

bad_positions.tsv:

	#Contig	start	end
	contig1	50	100
	contig2	75	100

Stages
------

The core SNP pipeline proceeds through the following stages:

1. Reference mapping using SMALT.
2. Variant calling using FreeBayes.
3. Checking variant calls and depth of coverage using SAMTools.
4. Aligning high-quality SNPs into a meta-alignment (pseudoalignment) of phylogenetically informative sites.
    1. If an invalid positions file is passed, remove any SNPs within the invalid positions.
5. Building a phylogenetic tree with PhyML.


Installation
------------

Please refer to the [Installation](INSTALL.md) document.

In addition, a virtual machine with all the necessary software to run the pipeline can be installed by following the instructions on https://github.com/apetkau/microbial-informatics-2014#running-the-labs.

Details
-------

The core SNP pipeline has a number of different modes of operation in addition to building core SNP phylogenies from reference mapping and variant calling.  These modes of operation are controlled by the __--mode__ parameter.  A list of these different modes of operation is given below.

* __prepare-fastq__:  Can be used to remove low-quality reads from FASTQ files and reduce the data size.  This can be used for a basic quality check of reads before performing reference mapping and variant calling.
* __mapping__:  Builds a core SNP phylogeny using reference mapping and variant calling.
* __orthomcl__:  Builds a core orthologous gene SNP phylogeny by multiply aligning orthologs identified using OrthoMCL and extracting phylogenetically informative sites.
* __blast__:  Builds a core orthologous gene SNP phylogeny by multiply aligning orthologs identified using a single-directional BLAST and extracting phylogenetically informative sites.

In addition to the above modes, data analysis can be re-submitted from any stage using the __--resubmit__ parameter.

### Mode: Prepare-FASTQ ###

This mode can be used to do some basic quality checks on FASTQ files before running through the reference mapping pipeline.  The stages that are run are as follows:

1. Removes poor quality reads and trims ends of reads.
2. Randomly samples reads from FASTQ files to reduce the dataset size to a user-configurable maximum coverage (estimated based on the reference genome length).
3. Runs FastQC on the quality-filtered and reduced reads dataset.
4. Generates a report for each of the isolates.

#### Command ####

To run this mode, the following command can be used.

	snp_phylogenomics_control --mode prepare-fastq --input-dir fastq/ --output cleaned_out --reference reference.fasta --config options.conf

The main output you will want to use includes:
* __cleaned_out/fastqc/fastqc_stats.csv__: A tab-deliminated report from FastQC on each isolate.
* __cleaned_out/downsampled_fastq__:  A directory containing all the cleaned and reduced FASTQ files.  This directory can be used as input to the mapping mode of the pipeline.

#### Input ####

The following is a list of input files and formats for the __prepare-fastq__ mode of the pipeline.

* __--input-dir fastq_reads/__:  A directory containing FASTQ-formatted DNA sequence reads.  Only one file per isolate (paired-end mapping not supported).

Example:

	fastq_reads/
		isolate1.fastq
		isolate2.fastq
		isolate3.fastq

* __--reference reference.fasta__:  A reference FASTA file.  This is used to estimate the coverage of each isolate for reducing the amount of data in each FASTQ file.
* __--config options.conf__:  A configuration file in [YAML](http://yaml.org/) format.  This is used to defined specific parameters for each stage of the _prepare-fastq_ mode.

Example:

	%YAML 1.1
	---
	max_coverage: 200
	trim_clean_params: '--numcpus 4 --min_quality 20 --bases_to_trim 10 --min_avg_quality 25 --min_length 36 -p 1'
	drmaa_params:
		general: "-V"
		trimClean: "-pe smp 4"

#### Output ####

* __--output cleaned_out__:  Defines the output directory to store the files for each stage.

The output directory structure looks as follows:

	cleaned_out/
		downsampled_fastq/
		fastqc/
		initial_fastq_dir/
		log/
		reference/
		run.properties
		stages/

A description of each of the directories and files are:

* __downsampled_fastq/__:  A directory containing the quality-filtered and data reduced fastq files.
* __fastqc/__:  A directory containing any of the FastQC results.
* __initial_fastq_dir/__:  A directory containing links to the initial input fastq files.
* __log/__:  A directory containing log files for each of the stages.
* __reference/__:  A directory containing the input reference file.
* __run.properties__:  A file containing all the parameters used to quality-filter the fastq files.
* __stages/__:  A directory containing files used to defined which stages of the _prepare-fastq_ mode have been completed.

### Mode: Mapping ###

#### Input ####

The following is a list of input files and formats for the pipeline.

* __--reference reference.fasta__:  A FASTA file containing the genome to be used for reference mapping.

Example:

	>contig1
	ATCGATCGATCGATCG
	ATCGATCGATCGATCG

* __--input-dir fastq_reads/__:  A directory containing FASTQ-formatted DNA sequence reads.  Only one file per isolate (paired-end mapping not supported).  The file name is used as the name in the final phylogenetic tree.

Example:

	fastq_reads/
		isolate1.fastq
		isolate2.fastq
		isolate3.fastq

* __--invalid-pos bad_positions.tsv__: A tab-separated values file format containing a list of positions to exclude from the analysis.  Any SNPs in these positions will be marked as 'invalid' in the variant table and will be excluded from the matrix of SNP distances and the alignment used to generate the phylogeny.  The contig IDs used in this file must correspond to the IDs used in the reference FASTA file.

Example:

	#ContigID	Start	End
	contig1	1	500
	contig2	50	100

* __--config options.conf__:  A configuration file which can be used to override the default parameters for the different stages.  This file must be in [YAML](http://yaml.org/) format.

Example:

	%YAML 1.1
	---
	min_coverage: 15
	freebayes_params: '--pvar 0 --ploidy 1 --left-align-indels --min-mapping-quality 30 --min-base-quality 30 --min-alternate-fraction 0.75'
	smalt_index: '-k 13 -s 6'
	smalt_map: '-n 24 -f samsoft -r -1'
	vcf2pseudo_numcpus: 4
	vcf2core_numcpus: 24
	trim_clean_params: '--numcpus 4 --min_quality 20 --bases_to_trim 10 --min_avg_quality 25 --min_length 36 -p 1'
	drmaa_params:
		general: "-V"
		vcf2pseudoalign: "-pe smp 4"
		vcf2core: "-pe smp 24"
		trimClean: "-pe smp 4"

#### Output ####

The detailed output directory tree looks as follows:

	pipeline_out/
		fastq/
		invalid/
		log/
		mapping/
		mpileup/
		phylogeny/
			pseudoalign.phy_phyml_stats.txt
			pseudoalign.phy_phyml_tree.txt
			pseudoalign.phy_phyml_tree.txt.pdf
		pseudoalign/
			matrix.csv
			pseudoalign.fasta
			pseudoalign.phy
			pseudoalign-positions.tsv
		reference/
		run.properties
		sam/
		stages/
		vcf/
		vcf2core/
			contig1.gff
		vcf-split/
        
The description of each of these directories/files are as follows:

* __fastq/__: A directory containing links to each of the input fastq files.
* __invalid/__:  A directory containing the invalid positions file used if it was passed to the pipeline.
* __log/__:  Log files for every stage of the pipeline.
* __mapping/__:  Files for each isolate containing the [SMALT](http://www.sanger.ac.uk/resources/software/smalt/) reference-mapping information.
* __mpileup/__:  Files generated from 'samtools mpileup' for each isolate.
* __phylogeny/__:  Files generated from PhyML when building the phylogeny.
    * __pseudoalign.phy_phyml_stats.txt__:  A statistics file generated by PhyML.
    * __pseudoalign.phy_phyml_tree.txt__:  The phylogenetic tree generated by PhyML in Newick format.
    * __pseudoalign.phy_phyml_tree.txt.pdf__:  A PDF of the phylogenetic tree, rendered using Figtree.
* __pseudoalign/__:  Contains the "pseudoalignment" of only phylogenetically informative sites used to generate the phylogeny, as well as other information about each of the sites.
    * __matrix.csv__:  A matrix of SNP distances between each isolate.
    * __pseudoalign.fasta__:  An alignment of phylogenetically informative sites in FASTA format.
    * __pseudoalign.phy__:  An alignment of phylogenetically informative sites, in phylip format.
    * __pseudoalign-positions.tsv__: A tab-separated values file containing a list of all positions identified by the pipeline.
* __reference/__:  A directory containing links to the reference FASTA file used by some of the tools.
* __run.properties__:  A properties file containing all the parameters used for the pipeline, in [YAML](http://yaml.org/) format.
* __sam/__:  SAM formated files generated by SMALT.
* __stages/__:  A directory of files indicating which stages have been completed by the pipeline.
* __vcf/__:  The VCF files produced by [FreeBayes](https://github.com/ekg/freebayes).
* __vcf2core/__:  Files used to generate an image of the core genome.
    * __contig1.gff__:  A GFF formatted file listing core genome locations on each contig.
* __vcf-split/__:  VCF files split up so that one single SNP is represented by one line.

The __matrix.csv__ file lists high-quality SNP distances between each combination of isolates.  An example of this file is given below.

Example: _matrix.csv_

	strain	isolate1	isolate2
	isolate1	0	5
	isolate2	5	0

The __pseudoalign-positions.tsv__ file lists all SNPs found within the pipeline and the corresponding contig/position combination.  The __status__ column lists the status of each position.  Only _valid_ position statuses are used to generate the alignment files.  The _filtered-coverage_ status defines a position (indicated by a - character) which had insufficient coverage to be included as a core SNP.  The _filtered-mpileup_ status defines a position (indicated by an N) which had conflicting variant calls between FreeBayes and SAMTools mpileup.  The _filtered-invalid_ status indicates that this position was filtered out due to belonging to one of the invalid position regions passed to the pipeline.

Example: _pseudoalign-positions.tsv_

	#Chromosome	Position	Status	Reference	isolate1	isolate2
	contig1	20	valid	A	A	T
	contig2	5	filtered-coverage	A	-	A
	contig2	35	filtered-mpileup	A	N	A
	contig2	40	filtered-invalid	A	C	A

The __vcf2core/*.gff__ files list the coordinates that were deteremend to be part of the core genome (based on the minimum coverage).

Example: _contig1.gff_

	task_2	.	region	10	100	100	+	0	
	task_2	.	region	150	200	100	+	0

### Resubmitting ###

In order to resubmit a particular run of the pipeline for data analysis from a particular stage the following command can be used.

	snp_phylogenomics_control --resubmit output_dir/ --start-stage starting-stage

The _output_dir/_ is the directory containing all the results of a previous run of the pipeline.  The _start-stage_ defines the starting stage for the new analysis.  For more details on the particular stages to use please run the command:

	snp_phylogenomics_control --help

