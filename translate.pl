#!/usr/bin/perl
use strict;
use lib ("/opt/rocks/lib/perl5/site_perl/5.10.1");
use Bio::SeqIO;
my $x=1;
opendir (DH, ".");
my @files = grep { /snps\d+$/i } readdir(DH);
for my $file (@files) {
my $in = new Bio::SeqIO(-file=>$file,-format=>"fasta");
my $out = new Bio::SeqIO(-file=>">$file" . ".faa", -format=>"fasta");
while (my $seq=$in->next_seq) {$out->write_seq($seq->translate);
}
}
