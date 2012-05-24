#!/usr/bin/perl

package Reporter;

use FindBin;
use lib "$FindBin::Bin/../lib";

use strict;

use File::Basename;
use Getopt::Long;
use Bio::Seq;
use Bio::SeqIO;
use Report;
use Report::Blast;
use Report::OrthoMCL;

my $verbose = 0;

__PACKAGE__->run() unless caller;

1;

sub usage
{
	print "Usage: ".basename($0)." -c <core_dir> -a <align_dir> -f <fasta_input_dir> [-o <output-file> -v]\n";
	print "\t-c|--core-dir:  The job data core directory\n";
	print "\t-a|--align-dir:  The job data align directory\n";
	print "\t-f|--fasta-input-dir:  The job data fasta input directory\n";
	print "\t-i|--input-dir:  The main input directory\n";
	print "\t-o|--output-file:  The output file (optional)\n";
	print "\t-m|--mode:  The mode (blast or orthomcl)\n";
	print "\t-v|--verbose:  Verbosity (optional)\n";
	print "\t-h|--help:  Help.\n";
	print "\nExample:\n";
	print "To generate a report for a job stored under sample_out/ use:\n";
	print "\t".basename($0)." --input-dir sample_out\n\n";
}

sub run
{
	my ($core_dir,$align_dir,$fasta_dir,$input_dir,$output_file,$mode,$help);

	if ( @_ && $_[0] eq __PACKAGE__)
	{
		GetOptions('c|core-dir=s' => \$core_dir,
			'a|align-dir=s' => \$align_dir,
			'o|output-file=s' => \$output_file,
			'f|fasta-input-dir=s' => \$fasta_dir,
			'i|input-dir=s' => \$input_dir,
			'm|mode=s' => \$mode,
			'v|verbose' => \$verbose,
			'h|help' => \$help) or die "Invalid options\n".usage;

		if (defined $help and $help)
		{
			print usage();
			exit 0;
		}
	}
	else
	{
		($core_dir,$align_dir,$fasta_dir,$input_dir,$output_file,$mode,$verbose) = @_;
	}

	die "No defined mode\n".usage if (not defined $mode);

	my $pseudoalign_dir = undef;
	my $reporter;

	if ($mode eq 'blast')
	{
		$reporter = new Report::Blast();
	}
	elsif ($mode eq 'orthomcl')
	{
		$reporter = new Report::OrthoMCL();
	}
	else
	{
		die "Mode $mode is invalid\n".usage;
	}

	$verbose = 0 if (not defined $verbose);

	if (defined $input_dir)
	{
		die "input-dir=$input_dir not a directory" if (not -d $input_dir);
		die "input-dir=$input_dir not valid job directory" if (not -e "$input_dir/run.properties");

		$core_dir = "$input_dir/core" if (not defined $core_dir);
		$align_dir = "$input_dir/align" if (not defined $align_dir);
		$fasta_dir = "$input_dir/fasta" if (not defined $fasta_dir);
		$pseudoalign_dir = "$input_dir/pseudoalign" if (not defined $pseudoalign_dir);
	}

	die "core-dir not defined\n".usage if (not defined $core_dir);
	die "core-dir=$core_dir not a valid directory\n".usage if (not -d $core_dir);
	die "align-dir not defined\n".usage if (not defined $align_dir);
	die "align-dir=$align_dir not a valid directory\n".usage if (not -d $align_dir);
	die "fasta-dir not defined\n".usage if (not defined $fasta_dir);
	die "fasta-dir=$fasta_dir not a valid directory\n".usage if (not -d $fasta_dir);
	die "pseudoalign-dir not defined\n".usage if (not defined $pseudoalign_dir);
	die "pseudoalign-dir=$pseudoalign_dir not a valid directory\n".usage if (not -d $pseudoalign_dir);

	my $output_fh = undef;
	if (defined $output_file)
	{
		open($output_fh, ">$output_file") or die "Could not open output file $output_file: $!";
	}
	else
	{
		open($output_fh, '>-') or die "Could not open stdout for writing";
	}

	my ($snp_locus_count,$total_snp_lengths) = $reporter->report_snp_locus($core_dir,$pseudoalign_dir);
	my ($core_locus_count,$total_core_lengths) = $reporter->report_core_locus($core_dir);
	my ($total_strain_loci,$total_features_lengths) = $reporter->report_initial_strains($fasta_dir);

	print $output_fh "# Numbers given as (core kept for analysis / total core / total)\n";
	foreach my $strain (sort keys %$total_strain_loci)
	{
		my $curr_total_loci = $total_strain_loci->{$strain};
		my $curr_total_length = $total_features_lengths->{$strain};
		my $curr_snp_lengths = $total_snp_lengths->{$strain};
		my $curr_core_lengths = $total_core_lengths->{$strain};

		print $output_fh "$strain: loci ($snp_locus_count / $core_locus_count / $curr_total_loci), sequence ($curr_snp_lengths / $curr_core_lengths / $curr_total_length)\n";
	}

	close($output_fh);
}
