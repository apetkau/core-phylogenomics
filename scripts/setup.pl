#!/usr/bin/env perl
# setup.pl
# Checks for Core Phylogenomics Pipeline dependencies and attempts to write a configuration file.

use FindBin;
use YAML::Tiny;
use File::Copy;
use File::Basename;

# dependency modules
# restrict version of bioperl due to differences in parsing files (phylip files and tests)
BEGIN {
	my $version = "1.006901";
	use Bio::Root::Version;
	die "Invalid BioPerl version $Bio::Root::Version::VERSION\nPlease install version $version"
		unless $Bio::Root::Version::VERSION eq $version;
}
use Bio::SeqIO;
use Getopt::Long;
use Parallel::ForkManager;
use Set::Scalar;
use Test::Harness;
use Vcf;
use YAML::Tiny;
use Schedule::DRMAAc;

my $script_dir = $FindBin::Bin;
my $config_dir = "$script_dir/../etc";
my $config_file = "$config_dir/pipeline.conf.default";
my $out_config_file = "$config_dir/pipeline.conf";
my $bin_dir = "$script_dir/../bin";
my $out_pipelinebin_file_default = "$bin_dir/snp_phylogenomics_control.example";
my $out_pipelinebin_file = "$bin_dir/snp_phylogenomics_control";
my $out_matrixbin_file_default = "$bin_dir/snp_matrix.example";
my $out_matrixbin_file = "$bin_dir/snp_matrix";

my $usage = "Usage: ".basename($0)." [--force] [--help]\n".
"Checks for software dependencies and generates configuration files and binary files in etc/ and bin/\n".
"Options:\n".
"--force: Force overwrite of configuration files\n".
"-h|--help:  Print usage statement\n";

my $force;
my $help;
if (not GetOptions('h|help' => \$help,
                'f|force' => \$force))
{
        die $usage;
}

$force = 0 if (not defined $force);
if (defined $help and $help)
{
        print $usage;
        exit 0;
}

# reading example configuration file.
my $yaml = YAML::Tiny->read($config_file);
die "Error: coult not read $config_file" if (not defined $yaml);
my $config = $yaml->[0];

print STDERR "Checking for Software dependencies...\n";

my $paths = $config->{'path'};
check_software($paths);

if (not $force and -e $out_config_file)
{
        print "Warning: file $out_config_file already exists ... overwrite? (Y/N) ";
        my $choice = <STDIN>;
        chomp $choice;
        if ("yes" eq lc($choic) or "y" eq lc($choice))
        {
                $yaml->write($out_config_file);
                print "Wrote new configuration to $out_config_file\n";
        }
        else
        {
                print "Did not write any new configuration file\n";
        }
}
else
{
        $yaml->write($out_config_file);
        print "Wrote new configuration to $out_config_file\n";
}

if ((not -e $out_pipelinebin_file) or $force)
{
	copy($out_pipelinebin_file_default,$out_pipelinebin_file) or die "Could not copy ".
		"$out_pipelinebin_file_default to $out_pipelinebin_file";
	chmod 0755, $out_pipelinebin_file;

	print STDERR "Wrote executable file to $out_pipelinebin_file\n";
}

if ((not -e $out_matrixbin_file) or $force)
{
	copy($out_matrixbin_file_default,$out_matrixbin_file) or die "Could not copy ".
		"$out_matrixbin_file_default to $out_matrixbin_file";
	chmod 0755, $out_matrixbin_file;

	print STDERR "Wrote executable file to $out_matrixbin_file\n";
}

print STDERR "Please add directory $bin_dir to PATH\n";

# checks software dependencies and fills in paths in YAML data structure
sub check_software
{
	my ($paths) = @_;
	
	# remote special paths where key name does not correspond to binary name
	delete $paths->{'vcftools-lib'};

	# Check for all other dependencies using the Unix `which` command
	foreach my $binary_name (keys %$paths)
	{
		print STDERR "Checking for $binary_name ...";
		my $binary_path = `which $binary_name`;
		chomp $binary_path;
		if (not -e $binary_path)
		{
			die "error: $binary_name could not be found on PATH";
		}
		else
		{
			print STDERR "OK\n";
			$paths->{$binary_name} = $binary_path;
		}
	}


	print STDERR "Checking for vcftools-lib ...";
	my $vcftools_lib = $INC{'Vcf.pm'};
	if (not -e $vcftools_lib)
	{
		die "error: vcftools-lib (with Vcf.pm) could not be found.";
	}
	else
	{
		print STDERR "OK\n";
		my $vcftools_lib_dir = dirname($vcftools_lib);
		$paths->{'vcftools-lib'} = $vcftools_lib_dir;
	}
}
