# Instructions on how to install core snp pipeline in Ubuntu 13.04

# Install a grid engine
# Based on instructions from http://scidom.wordpress.com/2012/01/18/sge-on-single-pc/
sudo apt-get install gridengine-master gridengine-exec gridengine-common gridengine-qmon gridengine-client gridengine-drmaa-dev 
# modified /etc/hosts so that localhost and `hostname` point to 127.0.0.1
# go through configuration and testing process

# adjusting parameters to run jobs faster
# run 'qconf -msconf' and adjust
#"schedule_interval                 0:0:15"
# to
#"schedule_interval                 0:0:5"
/etc/init.d/gridengine-master restart # restarts grid engine

# Install Schedule::DRMAAc
wget http://search.cpan.org/CPAN/authors/id/T/TH/THARSCH/Schedule-DRMAAc-0.81.tar.gz
tar -xvvzf Schedule-DRMAAc-0.81.tar.gz
cd Schedule-DRMAAc-0.81
export SGE_ROOT=/var/lib/gridengine

# Need to add setting of SGE_ROOT to global file so it's set every time
echo "export SGE_ROOT=/var/lib/gridengine" >> /etc/profile.d/gridengine.sh

# link up files from gridengine-drmaa package into SGE_ROOT to install module
ln -s /usr/lib/gridengine-drmaa/* $SGE_ROOT/

# link up header file
ln -s $SGE_ROOT/include/drmaa.h .

perl Makefile.PL
make
make test # tests need user 'root' or whoever's installing to be added when setting up grid engine to be able to submit jobs
make install

# core snp pipeline
# extra installation instructions can be found at: https://github.com/apetkau/core-phylogenomics/blob/development/INSTALL.md
cd /opt

# Install Perl modules
cpanm -S Parallel::ForkManager Set::Scalar YAML::Tiny Test::Harness

# Begin building all dependencies
apt-get install samtools blast2 clustalw mummer fastqc figtree phyml tabix vcftools

# link up executable clustalw (version 2) to clustalw2
ln -s /usr/bin/clustalw /usr/bin/clustalw2

# freebayes: commit f3e518688a0f04e711c3c3fbc002c8ded7e5f17e
apt-get install cmake g++ zlib1g-dev

cd /opt
git clone git://github.com/ekg/freebayes.git
cd freebayes
git checkout f3e518688a0f04e711c3c3fbc002c8ded7e5f17e
git submodule update --init --recursive
make
make # compiles successfully on second make
export PATH=/opt/freebayes/bin:$PATH

# SMALT
cd /opt
git clone git://git.code.sf.net/p/smalt/code smalt-code
cd smalt-code
./configure
make
make install

#############################
# core snp pipeline install #
#############################
cd /opt
git clone https://github.com/apetkau/core-phylogenomics.git
cd core-phylogenomics
git checkout development # checkout development branch
git submodule update --init --recursive

# Install BioPerl version 1.006901 specifically for pipeline
mkdir bioperl-1.006901
cpanm -S -L bioperl-1.006901 http://search.cpan.org/CPAN/authors/id/C/CJ/CJFIELDS/BioPerl-1.6.901.tar.gz
export PERL5LIB=/opt/bioperl-1.006901/lib/perl5/:$PERL5LIB
# add this to global profile to restrict to specific bioperl
echo "export PERL5LIB=/opt/bioperl-1.006901/lib/perl5/:\$PERL5LIB" >> /etc/profile.d/bioperl.sh

# In order to get pipeline to run and autogenerate figtree images we have to customize figtree
# to not require a graphics environment when running.  However, we want to enable the graphics environment
# when users are running the command `figtree`.  A simple solution is to have a pipeline-only version of figtree.
# This can be accomplished with the following commands.
# figtree
cd /opt
wget "http://tree.bio.ed.ac.uk/download.php?id=86&num=3" -O FigTree_v1.4.0.tgz
tar -xvvzf FigTree_v1.4.0.tgz
cp /opt/core-phylogenomics/doc/install-ubuntu/figtree /opt/FigTree_v1.4.0/bin/figtree
chmod +x /opt/FigTree_v1.4.0/bin/figtree
# only add this version of figtree to path right now so scripts/setup.pl script picks it up
export PATH=/opt/FigTree_v1.4.0/bin/:$PATH

# Likewise, the fastqc version that comes with ubuntu cannot be used (zips up results and does not provide a directory with them)
# so here's how to install it manually
# (only need to add to PATH for generating the config file from scripts/setup.pl)
cd /opt
wget http://www.bioinformatics.babraham.ac.uk/projects/fastqc/fastqc_v0.10.1.zip
unzip fastqc_v0.10.1.zip
chmod +x /opt/FastQC/fastqc
export PATH=/opt/FastQC/:$PATH

# switch back to core-pipeline
cd /opt/core-phylogenomics

# generate config file
perl scripts/setup.pl

# Run tests
perl t/run_tests.pl --tmp-dir /tmp

# add to PATH
export PATH=/opt/core-phylogenomics/bin:$PATH
# add vcf2pseudoalignment scripts to PATH
export PATH=/opt/core-phylogenomics/lib/vcf2pseudoalignment:$PATH
