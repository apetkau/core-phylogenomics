#!/usr/bin/env perl

package Stage::SmaltMapping;
use Stage;
use File::Basename;
@ISA = qw(Stage);

use strict;
use warnings;

sub new
{
        my ($proto, $job_properties, $logger) = @_;
        my $class = ref($proto) || $proto;
        my $self = $class->SUPER::new($job_properties, $logger);

        bless($self,$class);

	$self->{'_stage_name'} = 'reference-mapping';

        return $self;
}

sub execute
{
        my ($self) = @_;

	my $logger = $self->{'_logger'};
	my $stage = $self->get_stage_name;

	my $job_properties = $self->{'_job_properties'};
	my $script_dir = $job_properties->get_script_dir;
	my $smalt_launch = "$script_dir/../lib/reads2sams.pl";

	die "$smalt_launch does not exist" if (not -e $smalt_launch);

	my $input_fastq_dir = $job_properties->get_dir('fastq_dir');
	my $sam_dir = $job_properties->get_dir('sam_dir');
	my $bam_dir = $job_properties->get_dir('bam_dir');
	my $reference_dir = $job_properties->get_dir('reference_dir');
	my $reference_name = $job_properties->get_file('reference');
	my $output_dir = $job_properties->get_dir('mapping_dir');
	my $smalt_map = $job_properties->get_property('smalt_map');
	my $smalt_index = $job_properties->get_property('smalt_index');
	my $log_dir = $job_properties->get_dir('log_dir');

	die "No smalt_map params defined" if (not defined $smalt_map);
	die "No smalt_index params defined" if (not defined $smalt_index);
	die "Fastq directory $input_fastq_dir does not exist" if (not -e $input_fastq_dir);
	die "Output directory $output_dir does not exist" if (not -e $output_dir);

	$logger->log("\nStage: $stage\n",0);
	$logger->log("Mapping with smalt ...\n",0);

	my $smalt_path = $job_properties->get_file('smalt');
	$smalt_path = "smalt" if ((not defined $smalt_path) or (not -e $smalt_path));

	my $samtools_path = $job_properties->get_file('samtools');
	$samtools_path = "samtools" if ((not defined $samtools_path) or (not -e $samtools_path));

	my $smalt_command = $smalt_launch;
	my @smalt_params;

	opendir(my $fastq_h,$input_fastq_dir) or die "Could not open $input_fastq_dir";
	my @fastq_files = grep {/\.fastq$/i} readdir($fastq_h);
	closedir($fastq_h);

	my @bam_files = ();

	for my $file (@fastq_files)
	{
		my $file_base = basename($file, '.fastq');
		my $reference_file = "$reference_dir/$file_base.$reference_name";
		die "Could not find reference $reference_file" if (not -e $reference_file);
		my $fastq_file = "$input_fastq_dir/$file";
		my $bam_name = basename($file, '.fastq');
		my $bam_file = "$bam_dir/$bam_name.bam";
		my $output_smalt_dir = "$output_dir/$file";
		push(@bam_files,$bam_file);
		push(@smalt_params, ['--samtools-path', $samtools_path, '--bam-dir', $bam_dir, '--sam-dir', $sam_dir, '--smalt-path', $smalt_path, '-t', $reference_file, '-r', $fastq_file, '-d', $output_smalt_dir, '-i', $smalt_index, '--map', $smalt_map]);
	}

	$logger->log("\tSubmitting smalt jobs for execution ...\n",1);
	$self->_submit_jobs($smalt_command, 'smalt', \@smalt_params);

	# check for existence of bam files
	for my $file (@bam_files)
	{
		$logger->log("\tchecking for $file ...", 1);
		if (-e $file)
		{
			$logger->log("OK\n",1);
		}
		else
		{
			my $message = "error: no bam file $file found\n";
			$logger->log($message,1);
			die $message;
		}
	}

	$logger->log("done\n",1);
	$logger->log("...done\n",0);
}

1;
