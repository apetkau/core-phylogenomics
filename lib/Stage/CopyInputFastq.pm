#!/usr/bin/perl

package Stage::CopyInputFastq;
use Stage;
@ISA = qw(Stage);

use File::Copy;

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

	my $do_copy = $job_properties->get_property('input_copy');
	
	$logger->log("\nStage: $stage\n",0);

	die "input_fastq_dir is undefined" if (not defined $input_fastq_dir);
	opendir(my $input_dir, $input_fastq_dir) or die "Could not open directory $input_fastq_dir";
	my @files = grep {/\.fastq$/i} readdir($input_dir);
	closedir($input_dir);

	foreach my $file (@files)
	{
		if ($do_copy)
		{
			copy("$input_fastq_dir/$file", "$output_fastq_dir/$file") or die "Could not copy \"$input_fastq_dir/$file\" to \"$output_fastq_dir\": $!";
		}
		else
		{
			symlink("$input_fastq_dir/$file", "$output_fastq_dir/$file") or die "Could not copy \"$input_fastq_dir/$file\" to \"$output_fastq_dir\": $!";
		}
	}

	$logger->log("...done\n",0);
}

1;
