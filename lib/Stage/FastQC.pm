#!/usr/bin/perl

package Stage::FastQC;
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

	$self->{'_stage_name'} = 'fastqc';

        return $self;
}

sub execute
{
        my ($self) = @_;

	my $logger = $self->{'_logger'};
	my $stage = $self->get_stage_name;

	my $job_properties = $self->{'_job_properties'};
	my $script_dir = $job_properties->get_script_dir;
	my $fastqc_bin = $job_properties->get_file('fastqc');
	my $input_fastq_dir = $job_properties->get_dir('downsampled_fastq_dir');
	my $output_fastqc_dir = $job_properties->get_dir('fastqc_dir');
	my $java = $job_properties->get_file('java');
	my $ref_length = $job_properties->get_property('reference_length');
	my $reference = $job_properties->get_file('reference');

	my $fastqc_stats_bin = "$script_dir/../lib/fastqc_stats.pl";
	my $fastqc_stats_out = "$output_fastqc_dir/fastqc_stats.csv";

	$logger->log("\nStage: $stage\n",0);

	die "Reference length not defined" if (not defined $ref_length);
	die "Reference not defined" if (not defined $reference);
	die "No $fastqc_stats_bin exists" if (not -e $fastqc_stats_bin);
	die "No fastqc bin defined" if (not defined $fastqc_bin);
	die "No fastqc bin=$fastqc_bin exists" if (not -e $fastqc_bin);
	die "No java path defined" if (not defined $java);
	die "No java path=$java exists" if (not -e $java);

	my $reference_name = basename($reference, '.fasta');

	die "input_fastq_dir is undefined" if (not defined $input_fastq_dir);
	opendir(my $input_dir, $input_fastq_dir) or die "Could not open directory $input_fastq_dir";
	my @files = grep {/\.fastq$/i} readdir($input_dir);
	closedir($input_dir);

	# sub fastqc as series of cluster jobs
	my @summary_params = ();
	my @temp_fastqc_stats = ();
	my @fastqc_params = ();
	foreach my $file (@files)
	{
		my $fastq_file = "$input_fastq_dir/$file";
		my $name = basename($file,'.fastq');
		my $fastqc_dir = "$output_fastqc_dir/${name}_fastqc";
		my $temp_stats_file = "$output_fastqc_dir/fastqc_stats_tmp_$file";

		push(@fastqc_params,['-o', $output_fastqc_dir, $fastq_file, '-j', $java]);
		push(@summary_params,[$name,$fastq_file,$fastqc_dir,$ref_length,$temp_stats_file]);
		push(@temp_fastqc_stats,$temp_stats_file);
	}

	$self->_submit_jobs($fastqc_bin,'fastqc',\@fastqc_params);
	$self->_submit_jobs($fastqc_stats_bin,'summary',\@summary_params);

	foreach my $file (@temp_fastqc_stats)
	{
		die "Error generating stats file $file" if (not -e $file);
	}

	open(my $file_h,">$fastqc_stats_out") or die "Could not open $fastqc_stats_out: $!";
	print $file_h "# Coverage calculated by reference length $ref_length\n";
	print $file_h "Name\tFastQC\tEncoding\tReads\tTotalBP\tSeqLen\tCov\tDuplicate_%\tFailed_On\n";
	close($file_h);
	my $command = "cat ";
	foreach my $file (@temp_fastqc_stats)
	{
		$command .= "$file ";
	}
	$command .= " | sort -k 6 -n >> $fastqc_stats_out";
	$logger->log("\tRunning $command\n",1);
	system($command) == 0 or die "Could not execute $command\n";

	die "FastQC summary stats file $fastqc_stats_out does not exist" if (not -e $fastqc_stats_out);

	# cleanup
	foreach my $file (@temp_fastqc_stats)
	{
		unlink($file) or die "Could not delete $file: $!";
	}

	$logger->log("...done\n",0);
}

1;
