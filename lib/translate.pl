#!/usr/bin/perl
use strict;
use Bio::SeqIO;
use File::Basename qw(basename);

sub usage
{
	"Usage: ".basename($0)." <input dir> <output dir>\n";
}

my $input_dir = $ARGV[0];
my $output_dir = $ARGV[1];

die "No input dir defined\n".usage if (not defined $input_dir);
die "Input dir does not exist\n".usage if (not -e $input_dir);

die "No output dir defined\n".usage if (not defined $output_dir);
die "Output dir exists\n".usage if (-e $output_dir);

mkdir $output_dir if (not -e $output_dir);
opendir (DH, $input_dir) or die "Could not open $input_dir: $!";
my @files = grep { /fasta$/i } readdir(DH);
for my $file (@files)
{
	my $in = new Bio::SeqIO(-file=>"$input_dir/$file",-format=>"fasta");
	my $out = new Bio::SeqIO(-file=>">$output_dir/$file", -format=>"fasta");
	while (my $seq=$in->next_seq) {$out->write_seq($seq->translate(-complete => 1, -codontable_id =>11));}
}
