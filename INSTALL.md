Installation
============

The core SNP phylogenomics pipeline is written in Perl, designed to work within a Linux cluster computing environmnet and requires the installation of a lot of different programs as dependencies.

Steps
-----

In brief, the installation procedure involves performing the following steps:

1. Obtain code from github
2. Install all dependency software as well as dependency Perl modules.
3. Create a file __etc/pipeline.conf__ with the default configuration details and paths to all dependency software.
4. Create file __bin/snp_phylogenomics_control__ to launch the pipeline.
5. Add the __bin/__ directory to the PATH.
6. Test installation.

1. Obtaining the code
---------------------

The checkout the latest version of the pipeline, please use the following command:

	$ git clone --recursive https://github.com/apetkau/core-phylogenomics.git

2. Dependencies
---------------

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

### Perl Modules ###

* [Bioperl](http://www.bioperl.org/wiki/Main_Page)
* [Parallel::ForkManager](http://search.cpan.org/~szabgab/Parallel-ForkManager-1.05/lib/Parallel/ForkManager.pm)
* [Schedule::DRMAAc](http://search.cpan.org/~tharsch/Schedule-DRMAAc-0.81/Schedule_DRMAAc.pod)
* [Set::Scalar](http://search.cpan.org/~davido/Set-Scalar-1.26/lib/Set/Scalar.pm)
* [Tap::Harness](http://search.cpan.org/~ovid/Test-Harness-3.28/lib/TAP/Harness.pm)
* [YAML::Tiny](http://search.cpan.org/~ether/YAML-Tiny-1.56/lib/YAML/Tiny.pm)
* [Vcf](http://vcftools.sourceforge.net/)

3. Configuration
----------------

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
		vcftools-lib: /path/to/vcftools/perl
		fastqc: /path/to/FastQC/fastqc
		java: /path/to/bin/java
		shuf: /path/to/bin/shuf
		gview: /path/to/gview.jar
		nucmer: /path/to/mummer/nucmer
		delta-filter: /path/to/mummer/delta-filter
		show-aligns: /path/to/mummer/show-aligns
		show-snps: /path/to/mummer/show-snps
		mummer2vcf: /path/to/core-phylogenomics/lib/mummer2Vcf.pl
	
	processors: 24
	
	min_coverage: 15
	max_coverage: 200
	freebayes_params: '--pvar 0 --ploidy 1 --left-align-indels --min-mapping-quality 30 --min-base-quality 30 --min-alternate-fraction 0.75'
	smalt_index: '-k 13 -s 6'
	smalt_map: '-n 24 -f samsoft -r -1 -y 0.5'
	vcf2pseudo_numcpus: 4
	vcf2core_numcpus: 4
	trim_clean_params: '--numcpus 4 --min_quality 20 --bases_to_trim 10 --min_avg_quality 25 --min_length 36 -p 1'
	gview_style: '/path/to/core-phylogenomics/etc/original.gss'
	
	drmaa_params:
		general: "-V"
		vcf2pseudoalign: "-pe smp 4"
		vcf2core: "-pe smp 4"
		trimClean: "-pe smp 4"

4. Main pipeline script
-----------------------

Once the configuration file is setup, the main pipeline script must be modified in order to run the pipeline.  This can be done using the following command:

	$ cp bin/snp_phylogenomics_control.example bin/snp_phylogenomics_control
	
	# Modify snp_phylogenomics_control to include any necessary Perl libraries.

The __bin/snp_phylogenomics_control__ was created under the assumption that some dependency Perl modules may not be installed globally or there may be multiple Perl versions installed on the cluster (using http://perlbrew.pl/).  This script looks like:

```bash
	#!/bin/bash
	
	# Used only to be able to set extra perl5lib paths and then launch application
	# Rename to snp_phylogenomics_control (or whatever other name you want the executable to be
	# Note: if parametes contain any spaces and you quote them, won't be passed on properly
	
	SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
	
	#export PERL5LIB=$SCRIPT_DIR/../cpanlib/lib/perl5:$PERL5LIB
	
	$SCRIPT_DIR/../perl_bin/snp_phylogenomics_control.pl $@
```

This script simply sets up any custom environment variables necessary, then launches the "real" script at __perl_bin/snp_phylogenomics_control.pl__.

5. Set up PATH
--------------

In order to quickly launch the pipeline, the __bin/__ directory can be added to the PATH environment variable.  This can be done with a command similar to:

	export PATH=/path/to/pipeline/bin:$PATH

6. Testing
----------

The core SNP pipeline comes with a number of tests to check the installation.  To run the tests please use the command:

	$ ./t/run_tests.pl --tmp-dir /path/to/cluster-shared-dir
	pseudoalign ............ ok    
	snp_matrix ............. ok    
	variant_calls .......... ok    
	pipeline_blast ......... ok   
	pipeline_ortho ......... ok    
	pipeline_mapping ....... ok   
	pipeline_preparefastq .. ok   
	All tests successful.
	Files=7, Tests=154, 115 wallclock secs ( 0.17 usr  0.01 sys + 17.40 cusr  3.15 csys = 20.73 CPU)
	Result: PASS

The parameter __--tmp-dir__ defines the location to a common shared file system among all nodes of the cluster and will contain the temporary files for the tests.

Notes
-----

FigTree can be downloaded from [Figtree](http://tree.bio.ed.ac.uk/software/figtree/) and extracted to a directory structure that looks like:

	$ tree FigTree_v1.4.0
	FigTree_v1.4.0
	├── bin
	│   └── figtree
	├── carnivore.tree
	├── images
	│   └── figtree.png
	├── influenza.tree
	├── lib
	│   └── figtree.jar
	└── README.txt

The figtree path that needs to be put into the configuration file should point to the __FigTree_v1.4.0/bin/figtree__ file.  For example:

	%YAML 1.1
	---
	path:
		...
		figtree: /path/to/FigTree_v1.4.0/bin/figtree
		...

However, the __bin/figtree__ file won't properly execute the figtree Java Jar.  In order to fix this issue, replace the __bin/figtree__ file with the contents given below:

bin/figtree:
```bash
#!/bin/bash

ROOT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

java -Xms64m -Xmx512m -jar $ROOT_DIR/../lib/figtree.jar $*
```

This will properly setup the correct directories and run the 'java' command with the appropriate figtree.jar file.  Please also mark this file as executable with:

	$ chmod +x bin/figtree

To test out this fix, run the script with:

	$ ./bin/figtree -help
	                 FigTree v1.4.0, 2006-2012
	                  Tree Figure Drawing Tool
	                       Andrew Rambaut
	
	             Institute of Evolutionary Biology
	                  University of Edinburgh
	                     a.rambaut@ed.ac.uk
	
	                 http://tree.bio.ed.ac.uk/
	     Uses the Java Evolutionary Biology Library (JEBL)
	                http://jebl.sourceforge.net/
	 Thanks to Alexei Drummond, Joseph Heled, Philippe Lemey, 
	Tulio de Oliveira, Oliver Pybus, Beth Shapiro & Marc Suchard
	
	  Usage: figtree [-graphic <PDF|SVG|SWF|PS|EMF|GIF>] [-width <i>] [-height <i>] [-help] [<tree-file-name>] [<graphic-file-name>]
	    -graphic produce a graphic with the given format
	    -width the width of the graphic in pixels
	    -height the height of the graphic in pixels
	    -help option to print this message
	
	  Example: figtree test.tree
	  Example: figtree -graphic PDF test.tree test.pdf
	  Example: figtree -graphic GIF -width 320 -height 320 test.tree test.gif
