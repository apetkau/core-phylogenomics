Installation
============

The core SNP phylogenomics pipeline is designed to work within a Linux cluster computing environmnet and requires the installation of a lot of different programs as dependencies.

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

Configuration
-------------

The file __etc/pipeline.conf.default__ contains an example configuration file in [YAML](http://yaml.org/) format.  To setup the pipeline, please copy this file to __etc/pipeline.conf__ and add the locations for the dependency software and default parameters.  The locations for all the dependency software must be pointed towards a common path shared by all nodes on the cluster.

An example of the __pipeline.conf__ file is:

	%YAML 1.1
	---
	path:
		blastall: /path/to/blastall
		formatdb: /path/to/formatdb
		clustalw2: /path/to/clustalw2
		phyml: /path/to/phyml
		figtree: /path/to/figtree
		smalt: /path/to/smalt
		samtools: /path/to/samtools
		bcftools: /path/to/bcftools
		bgzip: /path/to/bgzip
		tabix: /path/to/tabix
		freebayes: /path/to/freebayes
		vcftools-lib: /path/to/vcftools-lib/perl/
		fastqc: /path/to/fastqc
		java: /path/to/java
		shuf: /path/to/shuf
		gview: /path/to/gview
		nucmer: /path/to/mummer/nucmer
		delta-filter: /path/to/mummer/delta-filter
		show-aligns: /path/to/mummer/show-aligns
		show-snps: /path/to/mummer/show-snps
		mummer2vcf: /path/to/core-pipeline/lib/mummer2Vcf.pl
	
	processors: 24
	
	min_coverage: 15
	max_coverage: 200
	freebayes_params: '--pvar 0 --ploidy 1 --left-align-indels --min-mapping-quality 30 --min-base-quality 30 --min-alternate-fraction 0.75'
	smalt_index: '-k 13 -s 6'
	smalt_map: '-n 24 -f samsoft -r -1'
	vcf2pseudo_numcpus: 4
	vcf2core_numcpus: 24
	trim_clean_params: '--numcpus 4 --min_quality 20 --bases_to_trim 10 --min_avg_quality 25 --min_length 36 -p 1'
	gview_style: '/path/to/core-pipeline/etc/original.gss'
	
	drmaa_params:
		general: "-V"
		vcf2pseudoalign: "-pe smp 4"
		vcf2core: "-pe smp 24"
		trimClean: "-pe smp 4"

Testing
-------

The core SNP pipeline comes with a number of tests to check the installation.  To run the tests please use the command:

	./t/run_tests.pl --tmp-dir /path/to/cluster-shared-dir

The parameter __--tmp-dir__ defines the location to a common shared file system among all nodes of the cluster and will contain the temporary files for the tests.