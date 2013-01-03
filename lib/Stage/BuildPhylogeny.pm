#!/usr/bin/env perl

package Stage::BuildPhylogeny;
use Stage;
@ISA = qw(Stage);

use File::Copy qw(copy move);

use strict;
use warnings;

sub new
{
        my ($proto, $job_properties, $logger) = @_;
        my $class = ref($proto) || $proto;
        my $self = $class->SUPER::new($job_properties, $logger);

        bless($self,$class);

	$self->{'_stage_name'} = 'build-phylogeny';

        return $self;
}

sub execute
{
        my ($self) = @_;

	my $logger = $self->{'_logger'};
	my $stage = $self->get_stage_name;

	my $job_properties = $self->{'_job_properties'};
	my $input_dir = $job_properties->get_dir('pseudoalign_dir');
	my $output_dir = $job_properties->get_dir('phylogeny_dir');
	my $log_dir = $job_properties->get_dir('log_dir');

	my $pseudoalign_file_name = "pseudoalign.phy";
	my $pseudoalign_file = "$input_dir/$pseudoalign_file_name";
	my $phyml_log = "$log_dir/phyml.log";

	$logger->log("\nStage: $stage\n",0);
	$logger->log("Building phylogeny ...\n",0);

	my $phyml = $job_properties->get_file('phyml');
	$phyml = 'phyml' if ((not defined $phyml) or (not -e $phyml));

	$logger->log("\tRunning phyml ...\n",1);
	$logger->log("\tMore information can be found at $phyml_log\n",1);
	die "Error: pseudoalign file $pseudoalign_file does not exist" if (not -e $pseudoalign_file);
	my $phylogeny_command = "$phyml --quiet -i \"$pseudoalign_file\" 1>\"$phyml_log\" 2>&1";
	$logger->log("\t$phylogeny_command",2);
	if(system($phylogeny_command) != 0)
	{
		print STDERR "Warning: could not execute $phylogeny_command, skipping stage \"$stage\"\n";
	}
	else
	{
		my $stats_name = "${pseudoalign_file_name}_phyml_stats.txt";
		my $stats_in = "$input_dir/$stats_name";
		my $stats_out = "$output_dir/$stats_name";
		my $tree_name = "${pseudoalign_file_name}_phyml_tree.txt";
		my $tree_in = "$input_dir/$tree_name";
		my $tree_out = "$output_dir/$tree_name";
		move($stats_in,$output_dir) or die "Could not move $stats_in to $output_dir: $!";
		move($tree_in,$output_dir) or die "Could not move $tree_in to $output_dir: $!";

		$logger->log("\tOutput can be found in $output_dir\n",0);
	}
	$logger->log("\t...done\n",1);


	$logger->log("...done\n",0);
}

1;
