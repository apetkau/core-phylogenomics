#!/usr/bin/perl

package Stage::CopyInputReference;
use Stage;
@ISA = qw(Stage);

use File::Copy;
use File::Basename;
use Bio::SeqIO;

use strict;
use warnings;

sub new
{
        my ($proto, $job_properties, $logger) = @_;
        my $class = ref($proto) || $proto;
        my $self = $class->SUPER::new($job_properties, $logger);

        bless($self,$class);

	$self->{'_stage_name'} = 'copy-input-reference';

        return $self;
}

sub reference_length
{
	my ($self,$reference) = @_;

	my $count = 0;
	my $in = Bio::SeqIO->new(-file=>"$reference",-format=>"fasta");
	die "Could not open reference file $reference" if (not defined $in);

	while(my $seq = $in->next_seq)
	{
		$count += $seq->length;
	}

	return $count;
}

sub execute
{
        my ($self) = @_;

	my $logger = $self->{'_logger'};
	my $stage = $self->get_stage_name;

	my $job_properties = $self->{'_job_properties'};
	my $input_file = $job_properties->get_abs_file('input_reference');
	my $output_file_path = $job_properties->get_file_dir('reference_dir','reference');
	
	$logger->log("\nStage: $stage\n",0);

	die "input reference file is undefined" if (not defined $input_file);
	die "input reference file does not exist" if (not -e $input_file);

	copy($input_file, $output_file_path) or die "Could not copy \"$input_file\" to \"$output_file_path\"";

	$logger->log("\tcalculating reference length\n",1);
	my $reference_length = $self->reference_length($output_file_path);
	if ($reference_length <= 0)
	{
		my $message = "\terror: invalid reference length $reference_length";
		$logger->log("$message\n",1);
		die $message;
	}
	$job_properties->set_property('reference_length',$reference_length);

	$logger->log("...done\n",0);
}

1;
