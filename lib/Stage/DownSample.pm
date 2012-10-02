#!/usr/bin/perl

package Stage::DownSample;
use Stage;
@ISA = qw(Stage);

use File::Copy;
use File::Basename;

use strict;
use warnings;

sub new
{
        my ($proto, $job_properties, $logger) = @_;
        my $class = ref($proto) || $proto;
        my $self = $class->SUPER::new($job_properties, $logger);

        bless($self,$class);

	$self->{'_stage_name'} = 'downsample';

        return $self;
}

sub execute
{
        my ($self) = @_;

	my $logger = $self->{'_logger'};
	my $stage = $self->get_stage_name;

	my $job_properties = $self->{'_job_properties'};
	my $fastq_dir = $job_properties->get_dir('cleaned_fastq');
	my $output_fastq_dir = $job_properties->get_dir('fastq_dir');
	my $shuf_path = $job_properties->get_file('shuf');
	my $max_coverage = $job_properties->get_property('max_coverage');
	my $ref_length = $job_properties->get_property('reference_length');
	my $script_dir = $job_properties->get_script_dir;

	my $downsample_launch = "$script_dir/../lib/extract_reads_for_coverage.pl";
	die "Error: downsample_launch=$downsample_launch does not exist" if (not -e $downsample_launch);

	$logger->log("\nStage: $stage\n",0);

	die "shuf_path is not defined" if (not defined $shuf_path);
	die "shuf_path does not exist" if (not -e $shuf_path);
	die "fastq_dir is undefined" if (not defined $fastq_dir);
	die "output_fastq_dir is undef " if (not defined $output_fastq_dir);
	die "$fastq_dir is undefined" if (not -e $fastq_dir);
	die "$output_fastq_dir does not exist" if (not -e $output_fastq_dir);
	die "Error ref_length is undefined" if (not defined $ref_length);
	die "Error ref_length=$ref_length is not a number" if ($ref_length !~ /^\d+$/);
	if (not defined $max_coverage)
	{
		$logger->log("\twarning: max_coverage undefined, setting to 100",0);
		$max_coverage = 100;
	}

	opendir(my $input_dir, $fastq_dir) or die "Could not open directory $fastq_dir";
	my @files = grep {/\.fastq$/i} readdir($input_dir);
	closedir($input_dir);

	my @downsample_params = ();
	foreach my $file (@files)
	{
		push(@downsample_params,[$shuf_path,$ref_length, ,$max_coverage, "$fastq_dir/$file", "$output_fastq_dir/$file"]);
	}

	$self->_submit_jobs($downsample_launch,'downsample',\@downsample_params);

	foreach my $file (@files)
	{
		die "Error: downsampled file $output_fastq_dir/$file does not exist" if (not -e "$output_fastq_dir/$file");
	}

	$logger->log("...done\n",0);
}

1;
