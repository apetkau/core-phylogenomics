#!/usr/bin/perl

package Stage::Mpileup;
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

	$self->{'_stage_name'} = 'mpileup';

        return $self;
}

sub execute
{
        my ($self) = @_;

	my $logger = $self->{'_logger'};
	my $stage = $self->get_stage_name;

	my $job_properties = $self->{'_job_properties'};
	my $script_dir = $job_properties->get_script_dir;
	my $mpileup_launch = "$script_dir/../lib/mpileup.pl";
	die "No mpileup=$mpileup_launch exists" if (not -e $mpileup_launch);

	my $bam_dir = $job_properties->get_dir('bam_dir');
	my $mpileup_dir = $job_properties->get_dir('mpileup_dir');
	my $reference_dir = $job_properties->get_dir('reference_dir');
	my $reference_name = $job_properties->get_file('reference');
	my $log_dir = $job_properties->get_dir('log_dir');

	die "Output directory $mpileup_dir does not exist" if (not -e $mpileup_dir);

	$logger->log("\nStage: $stage\n",0);
	$logger->log("Running mpileup ...\n",0);

	my @mpileup_params;
	my $samtools_path = $job_properties->get_file('samtools');
	$samtools_path = "samtools" if ((not defined $samtools_path) or (not -e $samtools_path));
	my $bcftools_path = $job_properties->get_file('bcftools');
	$bcftools_path = "bcftools" if ((not defined $bcftools_path) or (not -e $bcftools_path));
	my $bgzip_path = $job_properties->get_file('bgzip');
	$bgzip_path = "bgzip" if ((not defined $bgzip_path) or (not -e $bgzip_path));
	my $tabix_path = $job_properties->get_file('tabix');
	$tabix_path = "tabix" if ((not defined $tabix_path) or (not -e $tabix_path));

	opendir(my $bam_h,$bam_dir) or die "Could not open $bam_dir";
	my @bam_files = grep {/\.bam$/i} readdir($bam_h);
	closedir($bam_h);

	my @mpileup_files = ();

	for my $file (@bam_files)
	{
		my $file_base = basename($file, '.bam');
		my $reference_file = "$reference_dir/$file_base.$reference_name";
		die "Could not find reference $reference_file" if (not -e $reference_file);
		my $bam_file = "$bam_dir/$file";
		my $vcf_name = basename($file, '.bam');
		my $out_vcf = "$mpileup_dir/$vcf_name.vcf";
		push(@mpileup_files,$out_vcf);
		push(@mpileup_params, ['--samtools-path', $samtools_path, '--bcftools-path', $bcftools_path,
				      '--reference', $reference_file, '--bam', $bam_file, '--out-vcf', $out_vcf,
				      '--bgzip-path', $bgzip_path, '--tabix-path', $tabix_path]);
	}

	$logger->log("\tSubmitting mpileup jobs for execution ...\n",1);
	$self->_submit_jobs($mpileup_launch, 'mpileup', \@mpileup_params);

	# check to make sure everything ran properly
	for my $file (@mpileup_files)
	{
		my $bgzip_file = "$file.gz";
		$logger->log("\tchecking for $bgzip_file ...",1);
		if (-e $bgzip_file)
		{
			$logger->log("OK\n",1);
		}
		else
		{
			my $message = "error: no mpileup file $bgzip_file found\n";
			$logger->log($message,1);
			die $message;
		}
	}

	$logger->log("done\n",1);
	$logger->log("...done\n",0);
}

1;
