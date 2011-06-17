#!/usr/bin/perl
use strict;
use lib ("/opt/rocks/lib/perl5/site_perl/5.10.1");
use Bio::SeqIO;
use Cwd;
my $x=1;
use File::Copy;
my @files = <core*.ffn>;
open LOCUSMAP, ">locusmap.txt" || die "foo!: $!\n";
for my $file (@files) {
	my $in = new Bio::SeqIO(-file=>$file, -format=>"fasta");
	my  @orfs;
	while (my  $seq= $in->next_seq) {
	my ($orf) = $seq->desc =~ /^(.*?)\s/;
		push @orfs, $orf;
	}
	my  $orfs =  join " ", @orfs;
	print LOCUSMAP "$x: $orfs\n";
	my $newfilename = "snps$x";
	move($file, $newfilename);
	$x++;
}

