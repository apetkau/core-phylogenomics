#!/usr/bin/env perl
package Stage::MummerSNPS;
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

	$self->{'_stage_name'} = 'mummer-variant-calling';

        return $self;
}

sub execute
{
        my ($self) = @_;

	my $logger = $self->{'_logger'};
	my $stage = $self->get_stage_name;

	my $job_properties = $self->{'_job_properties'};
	my $script_dir = $job_properties->get_script_dir;
	my $mummersnps_launch = "$script_dir/../lib/mummer_snps.pl";
	die "No mummersnps=$mummersnps_launch exists" if (not -e $mummersnps_launch);


	my $log_dir = $job_properties->get_dir('log_dir');
	#check to see if have any data to work on, if not... we are done!
	my $contig_dir = $job_properties->get_dir('fasta_dir');
	opendir(my $contig_h,$contig_dir) or die "Could not open $contig_dir";
	my @contig_files = map { "$contig_dir/$_"} grep {/\.fasta$/} readdir($contig_h);
	closedir($contig_h);
	
	if (scalar @contig_files==0 )
	{
	    $logger->log("\nStage: $stage\n",0);
	    $logger->log("\nSkipping Stage: no input fasta were found or given\n",0);
	    $logger->log("done\n",1);
	    return;
	}

	my $vcf_split_dir = $job_properties->get_dir('vcf_split_dir');
	my $reference_dir = $job_properties->get_dir('reference_dir');
	my $reference_file = $job_properties->get_file('reference');
	my $ref_path = "$reference_dir/$reference_file";

	die "Output directory $vcf_split_dir does not exist" if (not -e $vcf_split_dir);

	$logger->log("\nStage: $stage\n",0);
	$logger->log("Running mummersnps ...\n",0);

	my @mummersnps_params;
	my $mummersnps_path = $job_properties->get_file('mummersnps');
	$mummersnps_path = "mummersnps" if ((not defined $mummersnps_path) or (not -e $mummersnps_path));
	my $bgzip_path = $job_properties->get_file('bgzip');
	$bgzip_path = "bgzip" if ((not defined $bgzip_path) or (not -e $bgzip_path));
	my $tabix_path = $job_properties->get_file('tabix');
	$tabix_path = "tabix" if ((not defined $tabix_path) or (not -e $tabix_path));
	my $nucmer_path = $job_properties->get_file('nucmer');
	$nucmer_path = "nucmer" if ((not defined $nucmer_path) or (not -e $nucmer_path));
	my $delta_filter_path = $job_properties->get_file('delta-filter');
	$delta_filter_path = "delta-filter" if ((not defined $delta_filter_path) or (not -e $delta_filter_path));
	my $showsnps_path = $job_properties->get_file('show-snps');
	$showsnps_path = "show-snps" if ((not defined $showsnps_path) or (not -e $showsnps_path));
	my $mummer2vcf_path = $job_properties->get_file('mummer2vcf');
	$mummer2vcf_path = "mummer2Vcf.pl" if ((not defined $mummer2vcf_path) or (not -e $mummer2vcf_path));


	my @vcf_files = ();

	for my $file (@contig_files)
	{
		my $vcf_name = basename($file, '.fasta');
		my $out_vcf_split = "$vcf_split_dir/$vcf_name.vcf";
		push(@vcf_files,$out_vcf_split);
		push(@mummersnps_params, [ '--reference', $ref_path,
					   '--delta-filter-path',$delta_filter_path,'--nucmer-path',$nucmer_path,
					   '--mummer2vcf' ,$mummer2vcf_path,'--show-snps-path', $showsnps_path, '--contig' , $file ,
				      '--bgzip-path', $bgzip_path, '--tabix-path', $tabix_path, '--out-vcf', $out_vcf_split]);
	}

	$logger->log("\tSubmitting mummersnps jobs for execution ...\n",1);
	$self->_submit_jobs($mummersnps_launch, 'mummersnps', \@mummersnps_params);

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
			my $message = "error: no mummersnps file $bgzip_file found\n";
			$logger->log($message,1);
			die $message;
		}
	}

	$logger->log("done\n",1);
	$logger->log("...done\n",0);
}

1;
