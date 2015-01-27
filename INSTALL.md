Installation
============

The core SNP phylogenomics pipeline is written in Perl, designed to work within a Linux cluster computing environmnet and requires the installation of a lot of different programs as dependencies.

Steps
-----

In brief, the installation procedure involves performing the following steps:

1. Obtain code from github
2. Install all dependency software as well as dependency Perl modules.
3. Run __scripts/setup.pl__ to check for dependencies, create configuration files and create executable wrapper scripts.
4. Check configuration and executable wrapper scripts for proper setup.
5. Add the __bin/__ directory to the PATH.
6. Test installation.

A full example of the steps need to install the pipeline in Ubuntu 13.04 can be found at [ubuntu-install-instructions.sh](doc/install-ubuntu/ubuntu-install-instructions.sh).

1. Obtaining the code
---------------------

The checkout the latest version (on development branch) of the pipeline, please use the following command:

	$ git clone https://github.com/apetkau/core-phylogenomics.git
	$ cd core-phylogenomics
	$ git checkout development
	$ git submodule update --init --recursive

2. Dependencies
---------------

The Core SNP pipeline makes use of the following dependencies.

### Perl Modules ###

* [BioPerl 1.6.901](http://search.cpan.org/~cjfields/BioPerl-1.6.901/)
* [Parallel::ForkManager](http://search.cpan.org/~szabgab/Parallel-ForkManager-1.05/lib/Parallel/ForkManager.pm)
* [Set::Scalar](http://search.cpan.org/~davido/Set-Scalar-1.26/lib/Set/Scalar.pm)
* [Test::Harness](http://search.cpan.org/~leont/Test-Harness/lib/TAP/Harness.pm)
* [YAML::Tiny](http://search.cpan.org/~ether/YAML-Tiny-1.56/lib/YAML/Tiny.pm)
* [Vcf](http://vcftools.sourceforge.net/)
* [Schedule::DRMAAc](http://search.cpan.org/~tharsch/Schedule-DRMAAc-0.81/Schedule_DRMAAc.pod)

These Perl modules can be installed using [cpanm](http://search.cpan.org/dist/App-cpanminus/lib/App/cpanminus.pm) with the following command:

	$ cpanm Parallel::ForkManager Set::Scalar YAML::Tiny Test::Harness
	$ cpanm http://search.cpan.org/CPAN/authors/id/C/CJ/CJFIELDS/BioPerl-1.6.901.tar.gz

The module **Schedule::DRMAAc** must be installed manually and requires the setup of a grid engine.  A guide for how to setup a grid engine on Ubuntu can be found at http://scidom.wordpress.com/2012/01/18/sge-on-single-pc/.  In short, for Ubuntu, installing Schedule::DRMAAc involves the following commands:

```bash
# Installs a grid engine on Ubuntu
# Based on instructions from http://scidom.wordpress.com/2012/01/18/sge-on-single-pc/
sudo -s
apt-get install gridengine-master gridengine-exec gridengine-common gridengine-qmon gridengine-client gridengine-drmaa-dev
# modified /etc/hosts so that localhost and `hostname` point to 127.0.0.1
# go through configuration process described in instructions, making sure to add 'root' and any other
#  user to the list of users who can submit jobs

# Install Schedule::DRMAAc
wget http://search.cpan.org/CPAN/authors/id/T/TH/THARSCH/Schedule-DRMAAc-0.81.tar.gz
tar -xvvzf Schedule-DRMAAc-0.81.tar.gz
cd Schedule-DRMAAc-0.81
export SGE_ROOT=/var/lib/gridengine

# link up files from gridengine-drmaa package into SGE_ROOT to install module
ln -s /usr/lib/gridengine-drmaa/* $SGE_ROOT/

# link up header file
ln -s $SGE_ROOT/include/drmaa.h .

perl Makefile.PL
make
make test # tests need user 'root' or whoever is installing to be added to be able to submit jobs
make install
```

The module **Vcf** must be installed manually from http://vcftools.sourceforge.net/ and must be added to your set of Perl library paths.  More information on this can be found in the https://github.com/apetkau/vcf2pseudoalignment documentation.

### Software ###

* [SAMTools](http://samtools.sourceforge.net/)
* [BLAST](http://blast.ncbi.nlm.nih.gov/Blast.cgi?CMD=Web&PAGE_TYPE=BlastDocs&DOC_TYPE=Download)
* [ClustalW2](https://www.ebi.ac.uk/Tools/phylogeny/clustalw2_phylogeny/help/)
* [MUMMer](http://mummer.sourceforge.net/manual/)
* [FastQC](http://www.bioinformatics.babraham.ac.uk/projects/fastqc/)
* [Figtree](http://tree.bio.ed.ac.uk/software/figtree/)
* [FreeBayes](https://github.com/ekg/freebayes)
* [Java](http://www.java.com/)
* [PhyML](http://code.google.com/p/phyml/)
* [GNU shuf](http://www.gnu.org/software/coreutils/manual/html_node/shuf-invocation.html)
* [SMALT](http://www.sanger.ac.uk/resources/software/smalt/)
* [Tabix](http://sourceforge.net/projects/samtools/files/tabix/)
* [VCFtools](http://vcftools.sourceforge.net/)

3. Dependency Check and Configuration
-------------------------------------

The script __scripts/check.pl__ can be used to automatically check for any of these dependencies and generate the required configuration files.  This script assumes the above dependency software are installed and available on the PATH.  To run this script, please use:

	$ perl setup.pl
	Checking for Software dependencies...
	Checking for nucmer ...OK
	Checking for freebayes ...OK
	Checking for show-aligns ...OK
	Checking for formatdb ...OK
	Checking for blastall ...OK
	Checking for figtree ...OK
	Checking for bcftools ...OK
	Checking for shuf ...OK
	Checking for bgzip ...OK
	Checking for java ...OK
	Checking for tabix ...OK
	Checking for smalt ...OK
	Checking for delta-filter ...OK
	Checking for clustalw2 ...OK
	Checking for fastqc ...OK
	Checking for samtools ...OK
	Checking for phyml ...OK
	Checking for show-snps ...OK
	Checking for mummer2Vcf ...OK
	Checking for vcftools-lib ...OK
	Wrote new configuration to scripts/../etc/pipeline.conf
	Wrote executable file to scripts/../bin/snp_phylogenomics_control
	Wrote executable file to scripts/../bin/snp_matrix
	Please add directory scripts/../bin to PATH

### Configuration ###

This script automatically attempts to write the configuration file __etc/pipeline.conf__.  This file is written in the [YAML](http://yaml.org/) format and may require some adjustments afterwards depending on the system you are installing the pipeline on.  In particular, you may want to adjust __processors__ and __*numcpus__ which defines the number of processors to use at certain stages of the pipeline as well as the __drmaa_params__ which defines specific DRMAAc parameters to pass when submitting to the cluster.  If these parameters do not apply the specific lines can easily be deleted.

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
	
	drmaa_params:
		general: "-V"
		vcf2pseudoalign: "-pe smp 4"
		vcf2core: "-pe smp 4"
		trimClean: "-pe smp 4"

### Main Pipeline Script ###

The __scripts/setup.pl__ script also attempts to automatically setup the wrappper pipeline scripts within __bin/__ used to run the pipeline.  These scripts are __bin/snp_phylogenomics_control__ and __bin/snp_matrix__.

The __bin/snp_phylogenomics_control__ was created under the assumption that some dependency Perl modules may not be installed globally or there may be multiple Perl versions installed on the cluster (using http://perlbrew.pl/).  This script looks like:

```bash
	#!/bin/bash
	
	# Used only to be able to set extra perl5lib paths and then launch application
	# Rename to snp_phylogenomics_control (or whatever other name you want the executable to be
	# Note: if parametes contain any spaces and you quote them, won't be passed on properly
	
	SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
	
	#export PERL5LIB=$SCRIPT_DIR/../cpanlib/lib/perl5:$PERL5LIB
	
	$SCRIPT_DIR/../scripts/snp_phylogenomics_control.pl $@
```

This script simply sets up any custom environment variables necessary, then launches the "real" script at __scripts/snp_phylogenomics_control.pl__.  The same is true of the __bin/snp_matrix__ script.

Please make sure these scripts make sense for your environment setup.

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

The parameter __--tmp-dir__ defines the location to a common shared file system among all nodes of the cluster and will contain the temporary files for the tests.  If something is wrong, the parameter __--keep-tmp__ can be used to keep all temporary data and log files for further inspection.

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
