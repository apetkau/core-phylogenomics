#!/usr/bin/perl

package Stage::GenerateReportOrthoMCL;
use Stage;
@ISA = qw(Stage);

use strict;
use warnings;

use File::Basename;
use Getopt::Long;

use Report;
use Report::OrthoMCL;

sub new
{
        my ($proto, $job_properties, $logger) = @_;
        my $class = ref($proto) || $proto;
        my $self = $class->SUPER::new($job_properties, $logger);

        bless($self,$class);

        $self->{'_stage_name'} = 'report';

        return $self;
}

sub execute
{
        my ($self) = @_;

        my $logger = $self->{'_logger'};
        my $stage = $self->get_stage_name;

        my $verbose = $self->{'_logger'}->{'verbose'};
        my $job_properties = $self->{'_job_properties'};
        my $working_dir = $job_properties->get_dir('pseudoalign_dir');
        my $script_dir = $job_properties->get_script_dir;
        my $core_dir = $job_properties->get_dir('core_dir');
        my $align_dir = $job_properties->get_dir('align_dir');
        my $fasta_dir = $job_properties->get_dir('fasta_dir');
        my $input_dir = $job_properties->get_job_dir;
	my $pseudoalign_dir = $job_properties->get_dir('pseudoalign_dir');
        my $output_file = "$working_dir/main.report";
	my $orthologs_group_file = $job_properties->get_file('orthologs_group');
        my $log_dir = $job_properties->get_dir('log_dir');

	my $groups_kept = $job_properties->get_property('groups_kept');
	my $groups_filtered = $job_properties->get_property('groups_filtered');

	my $reporter = new Report::OrthoMCL($logger);

        my $log_file = "$log_dir/generate_report.log";
	open(my $output_fh, ">$output_file") or die "Could not open output file $output_file: $!";

        $logger->log("\nStage: $stage\n",0);
        $logger->log("Generating report ...\n",0);

	my ($snp_locus_count,$total_snp_lengths) = $reporter->report_snp_locus($core_dir,$pseudoalign_dir, $logger);
	my ($core_locus_count,$total_core_lengths) = $reporter->report_core_locus($core_dir, $logger);
	my ($total_strain_loci,$total_features_lengths) = $reporter->report_initial_strains($fasta_dir, $logger);

	print $output_fh "# Numbers given as (core kept for analysis / total core / total)\n";
	if ((defined $groups_kept) and (defined $groups_filtered))
	{
		print $output_fh "OrthoMCL: kept $groups_kept / ".($groups_filtered + $groups_kept)." ortholog sets from file $orthologs_group_file\n";
	}
	else
	{
		print $output_fh "OrthoMCL: invalid data for values filtered/kept\n";
	}

	foreach my $strain (sort keys %$total_strain_loci)
	{
		my $curr_total_loci = $total_strain_loci->{$strain};
		my $curr_total_length = $total_features_lengths->{$strain};
		my $curr_snp_lengths = $total_snp_lengths->{$strain};
		my $curr_core_lengths = $total_core_lengths->{$strain};

		print $output_fh "$strain: loci ($snp_locus_count / $core_locus_count / $curr_total_loci), sequence ($curr_snp_lengths / $curr_core_lengths / $curr_total_length)\n";
	}

	close($output_fh);

        $logger->log("...done\n",0);
}

1;
