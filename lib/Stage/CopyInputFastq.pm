#!/usr/bin/env perl

package Stage::CopyInputFastq;
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

	$self->{'_stage_name'} = 'copy-input-fastq';

        return $self;
}

sub execute
{
        my ($self) = @_;

	my $logger = $self->{'_logger'};
	my $stage = $self->get_stage_name;

	my $job_properties = $self->{'_job_properties'};
	my $input_fastq_dir = $job_properties->get_abs_file('input_fastq_dir');
	my $output_fastq_dir = $job_properties->get_dir('fastq_dir');
	my $reference_dir = $job_properties->get_dir('reference_dir');
	my $reference = $job_properties->get_file('reference');

	my $do_copy = $job_properties->get_property('input_copy');
	
	$logger->log("\nStage: $stage\n",0);

	die "input_fastq_dir is undefined" if (not defined $input_fastq_dir);
	opendir(my $input_dir, $input_fastq_dir) or die "Could not open directory $input_fastq_dir";
	my @files = grep {/\.fastq$/i} readdir($input_dir);
	closedir($input_dir);

	# sub copy as series of cluster jobs
	if ($do_copy)
	{
		my @copy_params = ();
		foreach my $file (@files)
		{
			push(@copy_params,["$input_fastq_dir/$file", "$output_fastq_dir/$file"]);
		}

		$self->_submit_jobs('cp','copy-input',\@copy_params);
		foreach my $file (@files)
		{
			die "error: file $file did not successfully copy to $output_fastq_dir" if (not -e "$output_fastq_dir/$file");
		}
	}
	else
	{
		foreach my $file (@files)
		{
			symlink("$input_fastq_dir/$file", "$output_fastq_dir/$file") or die "Could not copy \"$input_fastq_dir/$file\" to \"$output_fastq_dir\": $!";
		}
	}

	# make new references
	foreach my $file(@files)
	{
		my $file_base = basename($file, '.fastq');
		my $new_reference = "$reference_dir/$file_base.$reference";
		if (not -e $new_reference)
		{
			symlink($reference,$new_reference) or die "Could not link $reference to $new_reference";
		}
	}

	$logger->log("...done\n",0);
}

1;
