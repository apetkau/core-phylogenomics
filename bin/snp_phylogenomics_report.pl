#!/usr/bin/perl

package Report;

use strict;

use File::Basename;
use Getopt::Long;
use Bio::Seq;
use Bio::SeqIO;

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
	print "\t-v|--verbose:  Verbosity (optional)\n";
	print "\t-h|--help:  Help.\n";
	print "\nExample:\n";
	print "To generate a report for a job stored under sample_out/ use:\n";
	print "\t".basename($0)." --input-dir sample_out\n\n";
}

sub process_ortholog_file
{
	my ($ortho_file, $total_locus_lengths) = @_;
	my $success = 0;

	if (not -e $ortho_file)
	{
		print "Warning: ortho_file=$ortho_file does not exist, skipping...";
		return $success;
	}

	print "processing $ortho_file\n" if ($verbose);
	my $in = new Bio::SeqIO(-file=>"$ortho_file", -format=>"fasta");
	my  @orfs;
	while (my $seq = $in->next_seq)
	{
		my ($orf) = $seq->desc =~ /^(.*?)\s/;
		my ($strain_id) = ($orf =~ /^([^\|]*)\|/);
		die "Error, found invalid strain_id=$strain_id in orf=$orf" if (not defined $strain_id or $strain_id eq '');
		if (not exists $total_locus_lengths->{$strain_id})
		{
			$total_locus_lengths->{$strain_id} = $seq->length;
		}
		else
		{
			$total_locus_lengths->{$strain_id} += $seq->length;
		}
	}

	$success = 1;
	return $success;
}

sub report_snp_locus
{
	my ($core_dir,$align_dir) = @_;
	my %total_locus_lengths;
	my $snp_locus_count = 0;

	# gets snps/core genes used in pipeline (assumes all files under align/ directory are used)
	opendir(my $align_dh, $align_dir) or die "Could not open directory $align_dir: $!";
	my @align_files = grep {/^snps\d+\.aln$/} readdir($align_dh);
	closedir($align_dh);

	# loci count
	for my $align_file (@align_files)
	{
		if ($align_file =~ /^(snps\d+)\.aln$/)
		{
			my $core_file = $1;
			if (not defined $core_file)
			{
				print "Warning: core_file for $align_dir/$align_file not defined, skipping...";
				next;
			}

			my $full_file_path = "$core_dir/$core_file";
			if (process_ortholog_file($full_file_path,\%total_locus_lengths))
			{
				$snp_locus_count++;
			}
		}
	}	

	return ($snp_locus_count,\%total_locus_lengths);
}

sub report_core_locus
{
	my ($core_dir) = @_;
	my %total_locus_lengths;
	my $core_locus_count = 0;

	opendir(my $core_dh, $core_dir) or die "Could not open directory $core_dir: $!";

	# loci count
	my $file = readdir($core_dh);
	while($file)
	{
		if ($file =~ /^core.*\.ffn$/ or $file =~ /^100pid_core.*\.ffn/)
		{
			my $full_file_path = "$core_dir/$file";
			if (process_ortholog_file($full_file_path,\%total_locus_lengths))
			{
				$core_locus_count++;
			}
		}

		$file = readdir($core_dh);
	}	

	return ($core_locus_count,\%total_locus_lengths);
}

sub report_initial_strains
{
	my ($fasta_dir) = @_;
	my %total_features_lengths;
	my %total_strain_loci;

	opendir(my $fasta_dh, $fasta_dir) or die "Could not open directory $fasta_dir: $!";
	my @files = readdir($fasta_dh);
	closedir($fasta_dh);

	for my $file (@files)
	{
		if ($file =~ /\.prepended\.fasta$/)
		{
			next if ($file =~ /^all/);

			my $strain_id = undef;
			my $full_file_path = "$fasta_dir/$file";
			print "processing $full_file_path\n" if ($verbose);
			my $in = new Bio::SeqIO(-file=>"$full_file_path", -format=>"fasta");
			while (my $seq = $in->next_seq)
			{
				my ($orf) = ($seq->display_id);
				my ($strain_id_curr) = ($orf =~ /^([^\|]*)\|/);
				if (not defined $strain_id)
				{
					$strain_id = $strain_id_curr;
				}
				else
				{
					die "Error: found two entries in file $full_file_path with different strain ids: $strain_id and $strain_id_curr" if ($strain_id_curr ne $strain_id);
				}

				if (not exists $total_features_lengths{$strain_id})
				{
					$total_features_lengths{$strain_id} = $seq->length;
					$total_strain_loci{$strain_id} = 1;
				}
				else
				{
					$total_features_lengths{$strain_id} += $seq->length;
					$total_strain_loci{$strain_id}++;
				}
			}
		}
	}	

	return (\%total_strain_loci,\%total_features_lengths);
}

sub run
{
	my ($core_dir,$align_dir,$fasta_dir,$input_dir,$output_file,$help);

	if ( @_ && $_[0] eq __PACKAGE__)
	{
		GetOptions('c|core-dir=s' => \$core_dir,
			'a|align-dir=s' => \$align_dir,
			'o|output-file=s' => \$output_file,
			'f|fasta-input-dir=s' => \$fasta_dir,
			'i|input-dir=s' => \$input_dir,
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
		($core_dir,$align_dir,$fasta_dir,$input_dir,$output_file,$verbose) = @_;
	}

	$verbose = 0 if (not defined $verbose);

	if (defined $input_dir)
	{
		die "input-dir=$input_dir not a directory" if (not -d $input_dir);
		die "input-dir=$input_dir not valid job directory" if (not -e "$input_dir/run.properties");

		$core_dir = "$input_dir/core" if (not defined $core_dir);
		$align_dir = "$input_dir/align" if (not defined $align_dir);
		$fasta_dir = "$input_dir/fasta" if (not defined $fasta_dir);
	}

	die "core-dir not defined\n".usage if (not defined $core_dir);
	die "core-dir=$core_dir not a valid directory\n".usage if (not -d $core_dir);
	die "align-dir not defined\n".usage if (not defined $align_dir);
	die "align-dir=$align_dir not a valid directory\n".usage if (not -d $align_dir);
	die "fasta-dir not defined\n".usage if (not defined $fasta_dir);
	die "fasta-dir=$fasta_dir not a valid directory\n".usage if (not -d $fasta_dir);

	my $output_fh = undef;
	if (defined $output_file)
	{
		open($output_fh, ">$output_file") or die "Could not open output file $output_file: $!";
	}
	else
	{
		open($output_fh, '>-') or die "Could not open stdout for writing";
	}

	my ($snp_locus_count,$total_snp_lengths) = report_snp_locus($core_dir,$align_dir);
	my ($core_locus_count,$total_core_lengths) = report_core_locus($core_dir);
	my ($total_strain_loci,$total_features_lengths) = report_initial_strains($fasta_dir);

	print $output_fh "# All numbers given as snp containing core/core/total\n";
	foreach my $strain (sort keys %$total_strain_loci)
	{
		my $curr_total_loci = $total_strain_loci->{$strain};
		my $curr_total_length = $total_features_lengths->{$strain};
		my $curr_snp_lengths = $total_snp_lengths->{$strain};
		my $curr_core_lengths = $total_core_lengths->{$strain};
		my $percent_snp_loci = sprintf "%02.3f",($snp_locus_count/$curr_total_loci);
		my $percent_snp_sequence = sprintf "%02.3f",($curr_snp_lengths/$curr_total_length);
		my $percent_core_loci = sprintf "%02.3f",($core_locus_count/$curr_total_loci);
		my $percent_core_sequence = sprintf "%02.3f",($curr_core_lengths/$curr_total_length);

		#print $output_fh "$strain: core loci $percent_core_loci% ($core_locus_count/$curr_total_loci), core sequence $percent_core_sequence% ($curr_core_lengths/$curr_total_length)\n";
		#print $output_fh "$strain: core snp loci $percent_snp_loci% ($snp_locus_count/$curr_total_loci), core snp sequence $percent_snp_sequence% ($curr_snp_lengths/$curr_total_length)\n";
		print $output_fh "$strain: loci ($snp_locus_count / $core_locus_count / $curr_total_loci), sequence ($curr_snp_lengths / $curr_core_lengths / $curr_total_length)\n";
	}

	close($output_fh);
}
