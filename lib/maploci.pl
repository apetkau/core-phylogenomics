#!/usr/bin/perl
use lib ("/opt/rocks/lib/perl5/site_perl/5.10.1");
use strict;
use Bio::SeqIO;
my @files = <core*.ffn>;
open LOCUSMAP, ">locusmap.txt" || die "cant open locusmap, foo1!!: $!\n";
for my $file (@files) {
	my $in = new Bio::SeqIO(-file=>$file, -format=>"fasta");
	my  @orfs;
	while (my  $seq= $in->next_seq) {
		my ($orf) = $seq->desc =~ /^(.*?)\s/;
		push @orfs, $orf;
		}
		my  $orfs =  join " ", @orfs;
		print LOCUSMAP "$orfs\n";
	
}
