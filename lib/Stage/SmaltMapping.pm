#!/usr/bin/perl

package Stage::SmaltMapping;
use Stage;
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
	my $reference_file = $job_properties->get_file_dir('reference_dir','reference');
	my $output_dir = $job_properties->get_dir('mapping_dir');
	my $threads = 24;
	if (not defined $threads)
	{
		warn "Warning: threads not defined, defaulting to 1 ...\n";
		$threads = 1;
	}
	my $log_dir = $job_properties->get_dir('log_dir');

	die "Reference file $reference_file does not exist" if (not -e $reference_file);
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

	for my $file (@fastq_files)
	{
		my $fastq_file = "$input_fastq_dir/$file";
		my $output_smalt_dir = "$output_dir/$file";
		push(@smalt_params, ['--samtools-path', $samtools_path, '--bam-dir', $bam_dir, '--sam-dir', $sam_dir, '--smalt-path', $smalt_path, '-t', $reference_file, '-r', $fastq_file, '-d', $output_smalt_dir, '-i', '-k 13 -s 6', '--map', "-n $threads -f samsoft"]);
	}

	$logger->log("\tSubmitting smalt jobs for execution ...\n",1);
	$self->_submit_jobs($smalt_command, 'smalt', \@smalt_params);
	$logger->log("done\n",1);
	$logger->log("...done\n",0);
}

1;
