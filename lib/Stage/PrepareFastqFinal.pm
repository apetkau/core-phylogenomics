#!/usr/bin/perl

package Stage::PrepareFastqFinal;
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

	$self->{'_stage_name'} = 'prepare-fastq-final';

        return $self;
}

sub execute
{
        my ($self) = @_;

	my $logger = $self->{'_logger'};

	my $job_properties = $self->{'_job_properties'};
	my $fastqc_dir = $job_properties->get_dir('fastqc_dir');
	my $downsample_dir = $job_properties->get_dir('downsampled_fastq_dir');

	$logger->log("\n================\n",0);
	$logger->log(  "= Output Files =",0);
	$logger->log("\n================\n",0);
	$logger->log("downsampled_files: $downsample_dir\n",0);
	$logger->log("fastqc: $fastqc_dir/fastqc_stats.csv\n",0);
}

1;
