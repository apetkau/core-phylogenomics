#!/usr/bin/env perl

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
	my $drmaa_params = $job_properties->get_property('drmaa_params');
	my $script_dir = $job_properties->get_script_dir;
	my $pseudoalign_launch = "$script_dir/../lib/vcf2pseudoalignment/vcf2pseudoalignment.pl";
	my $matrix_launch = "$script_dir/snp_matrix.pl";
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

	my $invalid_file = $job_properties->get_file_dir('invalid_pos_dir','invalid');

	my $mpileup_dir = $job_properties->get_dir('mpileup_dir');
	my $vcf_split_dir = $job_properties->get_dir('vcf_split_dir');
	my $reference_file = $job_properties->get_file_dir('reference_dir','reference');
	my $reference_name = basename($reference_file, '.fasta');
	my $pseudoalign_dir = $job_properties->get_dir('pseudoalign_dir');
	my $log_dir = $job_properties->get_dir('log_dir');
	my $out_base = "$pseudoalign_dir/pseudoalign";
	my $out_align = "$out_base.phy";
	my $out_matrix = "$pseudoalign_dir/matrix.csv";
	my $out_align_fasta = "$out_base.fasta";
	my $min_cov = $job_properties->get_property('min_coverage');
        my $num_cpus = $job_properties->get_property('vcf2pseudo_numcpus');
	my $drmaa_params_string = $drmaa_params->{'vcf2pseudoalign'};
	$drmaa_params_string = '' if (not defined $drmaa_params_string);
        
	if (not defined $min_cov)
	{
		$min_cov=5;
		$logger->log("warning: minimum coverage not defined, defaulting to $min_cov",0);
	}

        if ( not defined $num_cpus) {
            $num_cpus= 1;
        }
	die "Output directory $pseudoalign_dir does not exist" if (not -e $pseudoalign_dir);

	$logger->log("\nStage: $stage\n",0);
	$logger->log("Running vcf2pseudoalign ...\n",0);

	my @pseudoalign_params = ['--vcf-dir', $vcf_split_dir, '--mpileup-dir', $mpileup_dir, '-o', $out_base,
				  '-f', 'phylip', '-f', 'fasta', '-r', $reference_name, '-c', $min_cov, '-v','--numcpus',$num_cpus];
	
	#check to see if we have an invalid position file
	if ($invalid_file)
	{
	    push @{$pseudoalign_params[0]},'--invalid-pos';
	    push @{$pseudoalign_params[0]},$invalid_file;
	}
	
	$logger->log("\tSubmitting pseudoalignment job for execution ...\n",1);
	$self->_submit_jobs($pseudoalign_launch, 'pseudoalignment', \@pseudoalign_params, $drmaa_params_string);

	# check to make sure everything ran properly
	if (-e $out_align and -e $out_align_fasta)
	{
		$logger->log("\tpseudoalignments found in $out_align and $out_align_fasta file exists\n",0);
	}
	else
	{
		my $message = "\terror: pseudoalignment files $out_align and $out_align_fasta do not exist\n";
		$logger->log("\t$message",0);
		die;
	}

	$logger->log("\tBuilding SNP Matrix\n",0);
	$self->_submit_jobs($matrix_launch,'snp_matrix',[[$out_align,'-o',$out_matrix,'-v']]);

	if (not -e $out_matrix)
	{
		$logger->log("\terror: could not generate snp_matrix from $out_align\n",0);
		die;
	}

	$logger->log("done\n",1);
	$logger->log("...done\n",0);
}

1;
