#!/usr/bin/perl

package Stage::VariantCalling;
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

	$self->{'_stage_name'} = 'variant-calling';

        return $self;
}

sub execute
{
        my ($self) = @_;

	my $logger = $self->{'_logger'};
	my $stage = $self->get_stage_name;

	my $job_properties = $self->{'_job_properties'};
	my $script_dir = $job_properties->get_script_dir;
	my $freebayes_launch = "$script_dir/../lib/freebayes.pl";
	die "No freebayes=$freebayes_launch exists" if (not -e $freebayes_launch);

	my $bam_dir = $job_properties->get_dir('bam_dir');
	my $vcf_dir = $job_properties->get_dir('vcf_dir');
	my $vcf_split_dir = $job_properties->get_dir('vcf_split_dir');
	my $reference_file = $job_properties->get_file_dir('reference_dir','reference');
	my $log_dir = $job_properties->get_dir('log_dir');
	my $min_coverage = $job_properties->get_property('min_coverage');
	if (not defined $min_coverage)
        {
                $min_coverage=5;
                $logger->log("warning: minimum coverage not defined, defaulting to $min_coverage",0);
        }

	die "Reference file $reference_file does not exist" if (not -e $reference_file);
	die "Output directory $vcf_dir does not exist" if (not -e $vcf_dir);
	die "Output directory $vcf_split_dir does not exist" if (not -e $vcf_split_dir);

	$logger->log("\nStage: $stage\n",0);
	$logger->log("Running freebayes ...\n",0);

	my @freebayes_params;
	my $freebayes_path = $job_properties->get_file('freebayes');
	$freebayes_path = "freebayes" if ((not defined $freebayes_path) or (not -e $freebayes_path));
	my $bgzip_path = $job_properties->get_file('bgzip');
	$bgzip_path = "bgzip" if ((not defined $bgzip_path) or (not -e $bgzip_path));
	my $tabix_path = $job_properties->get_file('tabix');
	$tabix_path = "tabix" if ((not defined $tabix_path) or (not -e $tabix_path));

	opendir(my $bam_h,$bam_dir) or die "Could not open $bam_dir";
	my @bam_files = grep {/\.bam$/i} readdir($bam_h);
	closedir($bam_h);

	my @vcf_files = ();

	for my $file (@bam_files)
	{
		my $bam_file = "$bam_dir/$file";
		my $vcf_name = basename($file, '.bam');
		my $out_vcf = "$vcf_dir/$vcf_name.vcf";
		my $out_vcf_split = "$vcf_split_dir/$vcf_name.vcf";
		push(@vcf_files,$out_vcf_split);
		push(@freebayes_params, ['--freebayes-path', $freebayes_path, '--reference', $reference_file,
				      '--bam', $bam_file, '--out-vcf', $out_vcf,
				      '--bgzip-path', $bgzip_path, '--tabix-path', $tabix_path, '--out-vcf-split', $out_vcf_split, '--min-coverage', $min_coverage]);
	}

	$logger->log("\tSubmitting freebayes jobs for execution ...\n",1);
	$self->_submit_jobs($freebayes_launch, 'freebayes', \@freebayes_params);

	# check to make sure everything ran properly
	for my $file (@vcf_files)
	{
		my $bgzip_file = "$file.gz";
		$logger->log("\tchecking for $bgzip_file ...",1);
		if (-e $bgzip_file)
		{
			$logger->log("OK\n",1);
		}
		else
		{
			my $message = "error: no freebayes file $bgzip_file found\n";
			$logger->log($message,1);
			die $message;
		}
	}

	$logger->log("done\n",1);
	$logger->log("...done\n",0);
}

1;
