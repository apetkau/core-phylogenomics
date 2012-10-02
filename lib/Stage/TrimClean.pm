#!/usr/bin/perl

package Stage::TrimClean;
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

	$self->{'_stage_name'} = 'trim-clean';

        return $self;
}

sub execute
{
        my ($self) = @_;

	my $logger = $self->{'_logger'};
	my $stage = $self->get_stage_name;

	my $job_properties = $self->{'_job_properties'};
	my $fastq_dir = $job_properties->get_abs_file('input_fastq_dir');
	my $output_fastq_dir = $job_properties->get_dir('cleaned_fastq');
	my $trim_clean_params = "--min_quality 30 --bases_to_trim 10 --min_avg_quality 35 --min_length 21 -p 1";
	my $script_dir = $job_properties->get_script_dir;

	my $clean_launch = "$script_dir/../lib/run_assembly_trimClean.pl";
	die "Error: clean_launch=$clean_launch does not exist" if (not -e $clean_launch);

	my @clean_params_split = split(/\s+/,$trim_clean_params);

	$logger->log("\nStage: $stage\n",0);

	die "fastq_dir is undefined" if (not defined $fastq_dir);
	die "fastq_dir=$fastq_dir does not exist" if (not -e $fastq_dir);
	die "output_fastq_dir is undef " if (not defined $output_fastq_dir);
	die "$fastq_dir is undefined" if (not -e $fastq_dir);
	die "$output_fastq_dir does not exist" if (not -e $output_fastq_dir);
	opendir(my $input_dir, $fastq_dir) or die "Could not open directory $fastq_dir";
	my @files = grep {/\.fastq$/i} readdir($input_dir);
	closedir($input_dir);

	my @clean_params = ();
	foreach my $file (@files)
	{
		push(@clean_params,['-i', "$fastq_dir/$file", '-o', "$output_fastq_dir/$file",@clean_params_split]);
	}

	$self->_submit_jobs($clean_launch,'trim-clean',\@clean_params);

	opendir(my $output_dir, $output_fastq_dir) or die "Could not open directory $output_fastq_dir";
	my @output_files = grep {/\.fastq$/i} readdir($output_dir);
	closedir($output_dir);

	foreach my $file (@output_files)
	{
		if ($file =~ /\.singletons\.fastq$/)
		{
			$logger->log("\tdeleting $output_fastq_dir/$file",1);
			unlink("$output_fastq_dir/$file") or die "Could not delete $output_fastq_dir/$file: $!";
		}
	}

	foreach my $file (@files)
	{
		die "File $output_fastq_dir does not exist" if (not -e "$output_fastq_dir/$file");
	}

	$logger->log("...done\n",0);
}

1;
