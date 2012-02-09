#!/usr/bin/perl

package Stage::AlignOrthologs;
use Stage;
@ISA = qw(Stage);

use File::Basename qw(basename dirname);
use File::Copy qw(copy move);

use strict;
use warnings;

sub new
{
        my ($proto, $job_properties, $logger) = @_;
        my $class = ref($proto) || $proto;
        my $self = $class->SUPER::new($job_properties, $logger);

        bless($self,$class);

	$self->{'_stage_name'} = 'alignment';

        return $self;
}

sub execute
{
        my ($self) = @_;

	my $logger = $self->{'_logger'};
	my $stage = $self->get_stage_name;

	my $job_properties = $self->{'_job_properties'};
	my $core_dir = $job_properties->get_dir('core_dir');
	my $input_task_base = $job_properties->get_file_dir('core_dir', 'core_snp_base');
	my $output_dir = $job_properties->get_dir('align_dir');
	my $log_dir = $job_properties->get_dir('log_dir');
	my $script_dir = $job_properties->get_script_dir;

	die "Input files ${input_task_base}x do not exist" if (not -e "${input_task_base}1");
	die "Output directory $output_dir does not exist" if (not -e $output_dir);

	my $input_dir = dirname($input_task_base);

	$logger->log("\nStage: $stage\n",0);
	$logger->log("Performing multiple alignment of orthologs ...\n",0);

	my $max_snp_number = $self->_largest_snp_file($core_dir, $job_properties->get_file('core_snp_base'));
	die "Largest SNP number is invalid" if (not defined $max_snp_number or $max_snp_number <= 0);

	my $clustal_command = 'clustalw2';
	my $clustal_params = [];
	for (my $i = 1; $i <= $max_snp_number; $i++)
	{
		if (-e "${input_task_base}$i")
		{
			push(@$clustal_params, ["-infile=${input_task_base}$i"]);
		}
	}

	$logger->log("\tSubmitting $clustal_command for execution ...",1);
	$self->_submit_jobs($clustal_command, 'clustalw2', $clustal_params);
	$logger->log("done\n",1);

	opendir(my $align_dh, $input_dir) or die "Could not open $input_dir: $!";
	my @align_files = grep {/snps\d+\.aln/} readdir($align_dh);
	close($align_dh);
	$logger->log("\tMoving alignment files ...\n",1);
	foreach my $file_in (@align_files)
	{
		move("$input_dir/$file_in", "$output_dir/".basename($file_in)) or die "Could not move file $file_in: $!";
	}
	$logger->log("\t...done\n",1);

	my $log = "$log_dir/trim.log";
	require("$script_dir/../lib/trim.pl");
	$logger->log("\tTrimming alignments (see $log for details) ...\n",1);
	Trim::run($output_dir,$output_dir,$log);
	$logger->log("\t...done\n",1);

	$logger->log("...done\n",0);
}

sub _largest_snp_file
{
	my ($self,$core_dir, $core_snp_base) = @_;
	my $logger = $self->{'_logger'};

	$logger->log("\tGetting largest SNP file...\n",1);
	my $max = -1;
	opendir(my $dir_h,$core_dir);
	while(my $file = readdir $dir_h)
	{
		my ($curr_num) = ($file =~ /^$core_snp_base(\d+)$/);
		$max = $curr_num if (defined $curr_num and $curr_num > $max);
	}
	close ($dir_h);
	$logger->log("\t\tMax: $max\n",1);
	die "Error, no snp files" if ($max <= 0);

	$logger->log("\t...done\n",1);

	return $max;
}

1;
