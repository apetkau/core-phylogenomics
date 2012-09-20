#!/usr/bin/perl

package Stage::VcfPseudoalignment;
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

	$self->{'_stage_name'} = 'pseudoalign';

        return $self;
}

sub execute
{
        my ($self) = @_;

	my $logger = $self->{'_logger'};
	my $stage = $self->get_stage_name;

	my $job_properties = $self->{'_job_properties'};
	my $script_dir = $job_properties->get_script_dir;
	my $pseudoalign_launch = "$script_dir/../lib/vcf2pseudoalignment/vcf2pseudoalignment.pl";
	die "No pseudoalign_launch=$pseudoalign_launch exists" if (not -e $pseudoalign_launch);

	my $vcftools_lib = $job_properties->get_file('vcftools-lib');
	die "No vcftools-lib set in config" if ((not defined $vcftools_lib) or (not -d $vcftools_lib));
	if (defined $self->{'_perl_libs'})
	{
		$self->{'_perl_libs'} .= ":$vcftools_lib"; # set environment for Vcf.pm
	}
	else
	{
		$self->{'_perl_libs'} = "$vcftools_lib";
	}

	my $mpileup_dir = $job_properties->get_dir('mpileup_dir');
	my $vcf_split_dir = $job_properties->get_dir('vcf_split_dir');
	my $reference_file = $job_properties->get_file_dir('reference_dir','reference');
	my $reference_name = basename($reference_file, '.fasta');
	my $pseudoalign_dir = $job_properties->get_dir('pseudoalign_dir');
	my $log_dir = $job_properties->get_dir('log_dir');
	my $out_align = "$pseudoalign_dir/pseudoalign.phy";
	my $min_cov = 10;

	die "Output directory $pseudoalign_dir does not exist" if (not -e $pseudoalign_dir);

	$logger->log("\nStage: $stage\n",0);
	$logger->log("Running freebayes ...\n",0);

	my @pseudoalign_params = ['--vcf-dir', $vcf_split_dir, '--mpileup-dir', $mpileup_dir, '-o', $out_align,
				  '-f', 'phylip', '-r', $reference_name, '-c', $min_cov, '-v'];

	$logger->log("\tSubmitting pseudoalignment job for execution ...\n",1);
	$self->_submit_jobs($pseudoalign_launch, 'pseudoalignment', \@pseudoalign_params);

	# check to make sure everything ran properly
	if (-e $out_align)
	{
		$logger->log("\tpseudoalignment found in $out_align file exists\n",0);
	}
	else
	{
		my $message = "error: pseudoalignment file $out_align does not exist\n";
		$logger->log("\t$message",0);
		die;
	}

	$logger->log("done\n",1);
	$logger->log("...done\n",0);
}

1;
