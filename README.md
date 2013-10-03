Core SNP Phylogenomics
======================

The NML Core SNP phylogenomics pipeline provides a pipeline for identifying high-quality core SNPs among a set of bacterial isolates and generating phylogenetic trees from these SNPs.  The pipeline takes as input a reference genome (in FASTA format) and a set of DNA sequencing reads (in FASTQ format) and proceeds through a number of different stages to find core SNPs.

Quick Start
-----------


### Command ###

If you have a set of DNA sequencing reads, __fastq_reads/*.fastq__, and a reference file containing the DNA sequence of the genome to use for reference mapping, __reference.fasta__, then the following command can be used to generate a core SNP phylogeny.

	snp_phylogenomics_control --mode mapping --input-dir fastq_reads/ --output pipeline_out --reference reference.fasta

### Output ###

Once the pipeline is finished main output files you will want to look at include:

* __pipeline_out/pseudoalign/pseudoalign-positions.tsv__: A tab-separated file containing all variants identified and the positions of each variant on the reference genome.
* __pipeline_out/pseudoalign/matrix.csv__:  A tab-separated file containing a matrix of high-quality SNP distances between isolates.
* __pipeline_out/pseudoalign/pseudoalign.phy__: An alignment of variants for each input isolate in phylip format.
* __pipeline_out/phylogeny/pseudoalign.phy_phyml_tree.txt__:  A phylogenetic tree of the above alignment file generated using [ PhyML](http://code.google.com/p/phyml/).

### Alternative Commands ###

Alternatively, in addition to the above files, if you have a set of assembled contigs from isolates, __fasta_contigs/*.fasta__, that you wish to include in the analysis, you can run the pipeline with:

	snp_phylogenomics_control --mode mapping --input-dir fastq_reads/ --contig-dir fasta_contigs/  --output pipeline_out --reference reference.fasta

In addition, if you have a pre-defined set of positions on the reference genome you wish to exclude (repetitive regions, etc) in a tab-separated values file format (see detailed documentation below for a description of the file format) you can run the pipeline with the command:

	snp_phylogenomics_control --mode mapping --input-dir fastq_reads/ --contig-dir fasta_contigs/  --invalid-pos bad_positions.tsv --output pipeline_out --reference reference.fasta

Stages
------

The core SNP pipeline proceeds through the following stages:

1. Reference mapping using SMALT.
2. Variant calling using FreeBayes.
 a. For any assembled contigs passed to the pipeline, generates variant call files (VCF) using MUMMer alignments.
3. Checking variant calls and depth of coverage using SAMTools.
4. Aligning high-quality SNPs into a meta-alignment (pseudoalignment) of phylogenetically informative sites.
5. Building a phylogenetic tree with PhyML.

Dependencies
------------

The Core SNP pipeline makes use of the following dependencies.

### Software ###

* [SAMTools](http://samtools.sourceforge.net/)
* [BLAST](http://blast.ncbi.nlm.nih.gov/Blast.cgi?CMD=Web&PAGE_TYPE=BlastDocs&DOC_TYPE=Download)
* [ClustalW2](clustalw2)
* [MUMMer](http://mummer.sourceforge.net/manual/)
* [FastQC](http://www.bioinformatics.babraham.ac.uk/projects/fastqc/)
* [Figtree](http://tree.bio.ed.ac.uk/software/figtree/)
* [FreeBayes](https://github.com/ekg/freebayes)
* [GView](https://www.gview.ca)
* [Java](http://www.java.com/)
* [PhyML](http://code.google.com/p/phyml/)
* [GNU shuf](http://www.gnu.org/software/coreutils/manual/html_node/shuf-invocation.html)
* [SMALT](http://www.sanger.ac.uk/resources/software/smalt/)
* [Tabix](http://sourceforge.net/projects/samtools/files/tabix/)
* [VCFtools](http://vcftools.sourceforge.net/)

### PERL Modules ###

* [Bioperl](http://www.bioperl.org/wiki/Main_Page)
* [Parallel::ForkManager](http://search.cpan.org/~szabgab/Parallel-ForkManager-1.05/lib/Parallel/ForkManager.pm)
* [Schedule::DRMAAc](http://search.cpan.org/~tharsch/Schedule-DRMAAc-0.81/Schedule_DRMAAc.pod)
* [Set::Scalar](http://search.cpan.org/~davido/Set-Scalar-1.26/lib/Set/Scalar.pm)
* [Tap::Harness](http://search.cpan.org/~ovid/Test-Harness-3.28/lib/TAP/Harness.pm)
* [YAML::Tiny](http://search.cpan.org/~ether/YAML-Tiny-1.56/lib/YAML/Tiny.pm)
* [Vcf](http://vcftools.sourceforge.net/)

Details
-------

The core SNP pipeline has a number of different modes of operation in addition to building core SNP phylogenies from reference mapping and variant calling.  These modes of operation are controlled by the __--mode__ parameter.  A list of these different modes of operation is given below.

* __prepare-fastq__:  Can be used to remove low-quality reads from FASTQ files and reduce the data size.  This can be used for a basic quality check of reads before performing reference mapping and variant calling.
* __mapping__:  Builds a core SNP phylogeny using reference mapping and variant calling.
* __orthomcl__:  Builds a core orthologous gene SNP phylogeny by multiply aligning orthologs identified using OrthoMCL and extracting phylogenetically informative sites.
* __blast__:  Builds a core orthologous gene SNP phylogeny by multiply aligning orthologs identified using a single-directional BLAST and extracting phylogenetically informative sites.

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

* __--output cleaned_out__:  Defines the output directory to store the files for each stage.  The directory structure is given below.



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

* __--contig-dir contig_fasta/__: A directory containing assembled contigs to include for analysis.  Variants will be called using MUMMer.  Only one file per isolate.

Example:

	contig_fasta/
		isolate1.fasta
		isolate2.fasta
		isolate3.fasta

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
		pseudoalign/
		reference/
		run.properties
		sam/
		stages/
		vcf/
		vcf2core/
		vcf-split/
        
The description of each of these directories/files are as follows:

* __fastq/__: A directory containing links to each of the input fastq files.
* __invalid/__:  A directory containing the invalid positions file used if it was passed to the pipeline.
* __log/__:  Log files for every stage of the pipeline.
* __mapping/__:  Files for each isolate containing the [SMALT](http://www.sanger.ac.uk/resources/software/smalt/) reference-mapping information.
* __mpileup/__:  Files generated from 'samtools mpileup' for each isolate.
* __phylogeny/__:  Files generated from PhyML when building the phylogeny.
* __pseudoalign/__:  Contains the "pseudoalignment" of only phylogenetically informative sites used to generate the phylogeny, as well as other information about each of the sites.
* __reference/__:  A directory containing links to the reference FASTA file used by some of the tools.
* __run.properties__:  A properties file containing all the parameters used for the pipeline, in [YAML](http://yaml.org/) format.
* __sam/__:  SAM formated files generated by SMALT.
* __stages/__:  A directory of files indicating which stages have been completed by the pipeline.
* __vcf/__:  The VCF files produced by [FreeBayes](https://github.com/ekg/freebayes).
* __vcf2core/__:  Files used to generate an image of the core genome.
* __vcf-split/__:  VCF files split up so that one single SNP is represented by one line.