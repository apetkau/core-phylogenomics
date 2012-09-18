#!/usr/bin/perl

package Stage::CopyInputFasta;
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

	$self->{'_stage_name'} = 'copy-input-fasta';

        return $self;
}

sub execute
{
        my ($self) = @_;

	my $logger = $self->{'_logger'};
	my $stage = $self->get_stage_name;

	my $job_properties = $self->{'_job_properties'};
	my $input_fasta_dir = $job_properties->get_abs_file('input_fasta_dir');
	my $output_fasta_dir = $job_properties->get_dir('fasta_dir');
	
	$logger->log("\nStage: $stage\n",0);

	die "input_fasta_dir is undefined" if (not defined $input_fasta_dir);
	opendir(my $input_dir, $input_fasta_dir) or die "Could not open directory $input_fasta_dir";
	my @files = grep {/\.fasta$/} readdir($input_dir);
	closedir($input_dir);

	foreach my $file (@files)
	{
		copy("$input_fasta_dir/$file", $output_fasta_dir) or die "Could not copy \"$input_fasta_dir/$file\" to \"$output_fasta_dir\"";
	}

	$logger->log("...done\n",0);
}

1;
