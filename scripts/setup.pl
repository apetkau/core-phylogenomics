#!/usr/bin/env perl
# setup.pl
# Checks for Core Phylogenomics Pipeline dependencies and attempts to write a configuration file.
# Usage: check.pl > etc/pipeline.conf

use FindBin;
use YAML::Tiny;
use File::Copy;
use File::Basename;

# dependency modules
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
my $bin_dir = "$script_dir/../bin";
my $out_bin_file_default = "$bin_dir/snp_phylogenomics_control.example";
my $out_bin_file = "$bin_dir/snp_phylogenomics_control";

# reading example configuration file
my $yaml = YAML::Tiny->read($config_file);
die "Error: coult not read $config_file" if (not defined $yaml);
my $config = $yaml->[0];

print STDERR "Checking for Software dependencies...\n";

my $paths = $config->{'path'};
check_software($paths);

my $gview_style_path = "$script_dir/../etc/original.gss";
if (not -e $gview_style_path)
{
	die "error; could not find gview style in $gview_style_path";
}
else
{
	$config->{'gview_style'} = $gview_style_path;
}

print STDERR "Writing example etc/pipeline.conf file to STDOUT\n";
print $yaml->write_string;

#if (not -e $out_bin_file)
#{
#	copy($out_bin_file_default,$out_bin_file) or die "Could not copy ".
#		"$out_bin_file_default to $out_bin_file";
#	chmod 0766, $out_bin_file;
#
#	print "Wrote executable file to $out_bin_file\n";
#	print "Please add directory $bin_dir to PATH\n";
#}

# checks software dependencies and fills in paths in YAML data structure
sub check_software
{
	my ($paths) = @_;
	
	# remote special paths where key name does not correspond to binary name
	delete $paths->{'gview'};
	delete $paths->{'mummer2vcf'};
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

	print STDERR "Checking for GView ...";
	my $binary_name = "gview";
	my $binary_path = `which gview.jar`;
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

	print STDERR "Checking for mummer2Vcf ...";
	my $binary_name = "mummer2Vcf.pl";
	my $binary_path = "$script_dir/../lib/$binary_name";
	if (not -e $binary_path)
	{
		die "error: $binary_name could not be found in $binary_path";
	}
	else
	{
		print STDERR "OK\n";
		$paths->{$binary_name} = $binary_path;
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
