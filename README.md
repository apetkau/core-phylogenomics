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

In addition, a pre-processing mode can be run to filter out poor-quality reads and reduce the size of the dataset.  This runs the following stages.

1. Removes poor quality reads and trims ends of reads.
2. Randomly samples reads from FASTQ files to reduce the dataset size to a user-configurable maximum coverage (estimated based on the reference genome length).
3. Runs FastQC on the quality-filtered and reduced reads dataset.
4. Generates a report for each of the isolates.

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

### Input ###

The following is a list of input files and formats for the pipeline.

* __--input-dir fastq_reads/__:  A directory containing FASTQ-formatted DNA sequence reads.  Only one file per isolate (paired-end mapping not supported).
* __--contig-dir contig_fasta/__: A directory containing assembled contigs to include for analysis.  Variants will be called using MUMMer.  Only one file per isolate.  Must be named *.fasta.
* __--invalid-pos bad_positions.tsv__: A tab-separated values file format containing a list of positions to exclude from the analysis.  Any SNPs in these positions will be marked as 'invalid' in the variant table and will be excluded from the matrix of SNP distances and the alignment used to generate the phylogeny.  An example of this format (anything after a # symbol is ignored):
```
#ContigID	Start	End
contig1	1	500
contig2	50	100
```

### Output ###

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