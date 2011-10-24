#!/usr/bin/perl

package Report;

use strict;

use Getopt::Long;
use Bio::Seq;
use Bio::SeqIO;

__PACKAGE__->run() unless caller;

1;

sub usage
{
	print "Usage: $0 -c <core_dir> [-o <output-file>\n";
}

sub report_core_locus
{
	my ($core_dir) = @_;
	my %total_locus_lengths;
	my $core_locus_count = 0;

	# loci count
	opendir(my $core_dh, $core_dir) or die "Could not open directory $core_dir: $!";
	my @files = readdir($core_dh);
	closedir($core_dh);

	for my $file (@files)
	{
		if ($file =~ /^snps\d+$/)
		{
			my $full_file_path = "$core_dir/$file";
			my $in = new Bio::SeqIO(-file=>"$full_file_path", -format=>"fasta");
			my  @orfs;
			while (my $seq = $in->next_seq)
			{
				my ($orf) = $seq->desc =~ /^(.*?)\s/;
				my ($strain_id) = ($orf =~ /^([^\|]*)\|/);
				die "Error, found invalid strain_id=$strain_id in orf=$orf" if (not defined $strain_id or $strain_id eq '');
				if (not exists $total_locus_lengths{$strain_id})
				{
					$total_locus_lengths{$strain_id} = $seq->length;
				}
				else
				{
					$total_locus_lengths{$strain_id} += $seq->length;
				}
			}
			$core_locus_count++;
		}
	}	

	return ($core_locus_count,\%total_locus_lengths);
}

sub run
{
	my ($core_dir,$output_file);

	if ( @_ && $_[0] eq __PACKAGE__)
	{
		GetOptions('c|core-dir=s' => \$core_dir,
			'o|output-file=s' => \$output_file) or die "Invalid options\n".usage;
	}
	else
	{
		($core_dir,$output_file) = @_;
	}

	die "core-dir not defined\n".usage if (not defined $core_dir);
	die "core-dir=$core_dir not a valid directory\n".usage if (not -d $core_dir);

	my $output_fh = undef;
	if (defined $output_file)
	{
		open($output_fh, ">$output_file") or die "Could not open output file $output_file: $!";
	}
	else
	{
		open($output_fh, '>-') or die "Could not open stdout for writing";
	}

	my ($core_locus_count,$total_locus_lengths) = report_core_locus($core_dir);

	print $output_fh "Loci Compared: $core_locus_count\n";
	foreach my $strain (sort keys %$total_locus_lengths)
	{
		print $output_fh "bp in core of $strain: ",$total_locus_lengths->{$strain},"\n";
	}

	close($output_fh);
}
