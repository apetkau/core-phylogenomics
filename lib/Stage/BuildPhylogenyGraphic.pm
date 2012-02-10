#!/usr/bin/perl

package Stage::BuildPhylogenyGraphic;
use Stage;
@ISA = qw(Stage);

use strict;
use warnings;

sub new
{
        my ($proto, $job_properties, $logger) = @_;
        my $class = ref($proto) || $proto;
        my $self = $class->SUPER::new($job_properties, $logger);

        bless($self,$class);

	$self->{'_stage_name'} = 'phylogeny-graphic';

        return $self;
}

sub execute
{
        my ($self) = @_;

	my $logger = $self->{'_logger'};
	my $stage = $self->get_stage_name;

	my $job_properties = $self->{'_job_properties'};
	my $working_dir = $job_properties->get_dir('phylogeny_dir');
	my $log_dir = $job_properties->get_dir('log_dir');

	my $log_file = "$log_dir/figtree.log";

	my $tree_file = "$working_dir/pseudoalign.phy_phyml_tree.txt";

	$logger->log("\nStage: $stage\n",0);
	$logger->log("Building phylogeny tree graphic ...\n",0);

	my $figtree = $job_properties->get_file('figtree');
	$figtree = 'figtree' if ((not defined $figtree) or (not -e $figtree));

	$logger->log("\tGenerating image with figtree ...\n",1);
	$logger->log("\tMore information can be found at $log_file\n",1);
	die "Error: file $tree_file does not exist" if (not -e $tree_file);
	my $tree_image = "$tree_file.pdf";
	my $figtree_command = "$figtree -graphic PDF \"$tree_file\" \"$tree_image\" 1>\"$log_file\" 2>&1";
	$logger->log("\t$figtree_command",2);
	if(system($figtree_command) != 0)
	{
		print STDERR "Warning: Could not generate image using figtree";
	}
	else
	{
		$logger->log("\tphylogenetic tree image can be found at $tree_image\n",0);
	}
	$logger->log("\t...done\n",1);
	$logger->log("...done\n",0);
}

1;
