#!/usr/bin/env perl

package Stage::VcfCore;
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
	my $drmaa_params = $job_properties->get_property('drmaa_params');
	my $script_dir = $job_properties->get_script_dir;
	my $vcf2core_launch = "$script_dir/../lib/vcf2pseudoalignment/vcf2core.pl";
	die "No vcf2core_launch=$vcf2core_launch exists" if (not -e $vcf2core_launch);

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

	my $gview = $job_properties->get_file('gview');
	die "Could not find gview jar file" if (not -e $gview);

	my $gview_style = $job_properties->get_property('gview_style');
	die "Could not find gview stylesheet file" if (not -e $gview_style);

	my $mpileup_dir = $job_properties->get_dir('mpileup_dir');
	my $reference_file = $job_properties->get_file_dir('reference_dir','reference');

	my $core_dir = $job_properties->get_dir('vcf2core_dir');

	my $log_dir = $job_properties->get_dir('log_dir');

	my $min_cov = $job_properties->get_property('min_coverage');
        my $num_cpus = $job_properties->get_property('vcf2core_numcpus');
	my $drmaa_params_string = $drmaa_params->{'vcf2core'}; #TODO add to config
	$drmaa_params_string = '' if (not defined $drmaa_params_string);
        
	if (not defined $min_cov)
	{
		$min_cov=5;
		$logger->log("warning: minimum coverage not defined, defaulting to $min_cov",0);
	}

        if ( not defined $num_cpus) {
            $num_cpus= 1;
        }
	die "Output directory $core_dir does not exist" if (not -e $core_dir);

	$logger->log("\nStage: $stage\n",0);
	$logger->log("Running vcf2core ...\n",0);

	my @core_params = ['--mpileup-dir', $mpileup_dir, '-o', $core_dir,
				  '-i', $reference_file,'--gview_path' , $gview, '--gview_style' , $gview_style, '-c', $min_cov, '-v','--numcpus',$num_cpus];

	$logger->log("\tSubmitting vcf2core job for execution ...\n",1);
	$self->_submit_jobs($vcf2core_launch, 'vcf2core', \@core_params, $drmaa_params_string);

	# check to make sure everything ran properly
#	if (-e $out_align and -e $out_align_fasta)
#	{
#		$logger->log("\tpseudoalignments found in $out_align and $out_align_fasta file exists\n",0);
#	}
#	else
#	{
#		my $message = "\terror: pseudoalignment files $out_align and $out_align_fasta do not exist\n";
#		$logger->log("\t$message",0);
#		die;
#	}


	$logger->log("done\n",1);
	$logger->log("...done\n",0);
}

1;
