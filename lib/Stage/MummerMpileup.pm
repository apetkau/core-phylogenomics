#!/usr/bin/env perl
package Stage::MummerMpileup;
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

	$self->{'_stage_name'} = 'mummer-align-calling';

        return $self;
}

sub execute
{
        my ($self) = @_;

	my $logger = $self->{'_logger'};
	my $stage = $self->get_stage_name;

	my $job_properties = $self->{'_job_properties'};
	my $script_dir = $job_properties->get_script_dir;
	my $mummer_pileup_launch = "$script_dir/../lib/mummer_mpileup.pl";
	die "No mummerpileup=$mummer_pileup_launch exists" if (not -e $mummer_pileup_launch);

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

	my $mpileup_dir = $job_properties->get_dir('mpileup_dir');
	my $reference_dir = $job_properties->get_dir('reference_dir');
	my $reference_file = $job_properties->get_file('reference');
	my $ref_path = "$reference_dir/$reference_file";
	my $invalid_file = $job_properties->get_file_dir('invalid_pos_dir','invalid');
	die "Output directory $mpileup_dir does not exist" if (not -e $mpileup_dir);

	$logger->log("\nStage: $stage\n",0);
	$logger->log("Running mummer_pileup ...\n",0);

	my @mummer_pileup_params;
	my $mummer_pileup_path = $job_properties->get_file('mummer_pileup');
	$mummer_pileup_path = "mummer_pileup.pl" if ((not defined $mummer_pileup_path) or (not -e $mummer_pileup_path));
	my $bgzip_path = $job_properties->get_file('bgzip');
	$bgzip_path = "bgzip" if ((not defined $bgzip_path) or (not -e $bgzip_path));
	my $tabix_path = $job_properties->get_file('tabix');
	$tabix_path = "tabix" if ((not defined $tabix_path) or (not -e $tabix_path));
	my $nucmer_path = $job_properties->get_file('nucmer');
	$nucmer_path = "nucmer" if ((not defined $nucmer_path) or (not -e $nucmer_path));
	my $showaligns_path = $job_properties->get_file('show-aligns');
	$showaligns_path = "show-aligns" if ((not defined $showaligns_path) or (not -e $showaligns_path));



	my @vcf_files = ();

	for my $file (@contig_files)
	{
		my $vcf_name = basename($file, '.fasta');
		my $out_mpileup = "$mpileup_dir/$vcf_name.vcf";
		push(@vcf_files,$out_mpileup);
		push(@mummer_pileup_params, [ '--reference', $ref_path,'--contig' ,$file,,'-s',$nucmer_path,
					   '--show-align-path', $showaligns_path, '--contig' , $file,
				      '--bgzip-path', $bgzip_path, '--tabix-path', $tabix_path, '--out-vcf', $out_mpileup]);
	}


	if ($invalid_file) {
	    push @{$mummer_pileup_params[0]},$invalid_file;
	}


	$logger->log("\tSubmitting mummer_pileup jobs for execution ...\n",1);
	$self->_submit_jobs($mummer_pileup_launch, 'mummer_pileup', \@mummer_pileup_params);

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
			my $message = "error: no mummer_pileup file $bgzip_file found\n";
			$logger->log($message,1);
			die $message;
		}
	}

	$logger->log("done\n",1);
	$logger->log("...done\n",0);
}

1;
