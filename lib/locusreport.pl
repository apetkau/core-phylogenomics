#!/usr/bin/perl
use strict;
use lib ("/opt/rocks/lib/perl5/site_perl/5.10.1");
use Bio::AlignIO;
use Bio::SimpleAlign;
use Bio::LocatableSeq;
use Bio::SeqIO;
my $columncounter=1;
my $strainid = shift @ARGV;
use Cwd;
use File::Copy;
my $dir = getcwd; 
opendir (DH, $dir);
my @files = sort {&matchnum($a) <=> &matchnum($b)} grep { /trimmed$/i } readdir(DH);
my @columns;
my %longseq;
open (OUT, ">locusreport.txt");
my $locuscounter = 1;
for my $file (@files) {
	my $in = new Bio::AlignIO(-file=>"$file", -format=>"clustalw");
    $file =~ /(.*?)\.aln.trimmed$/;
	my $seqin = new Bio::SeqIO(-file=>"$1",-format=>"fasta");
	my %desc_recorder;
	 while (my $seq2= $seqin->next_seq) {
		if ($strainid) {
		$desc_recorder{desc} = $seq2->desc if $seq2->desc and $seq2->display_id =~ /$strainid/;
		}else
		{$desc_recorder{desc} = $seq2->desc if $seq2->desc}
		   push @{$desc_recorder{acc}}, $seq2->display_id;
	 }
	my @columns;
	my $aln = $in->next_aln;
	for my $seq ($aln->each_alphabetically) {
		my @chars = split undef, $seq->seq;
		for (my $x=0;$x<@chars;$x++){
			$columns[$x] .= $chars[$x];		
		}
	}
	my @minors;
	my @pseudoalign;
	my @colcount;
	column: for my $column (@columns) {
	 	my @chars = split undef, $column;
	 	my %char;
	 	map {$char{$_}++} @chars;
			 #dont include unless minor snp >=1 or if thereis a gap character
			my $lowest;
			(my $minorsnp) = sort{$char{$a} <=> $char{$b}} keys %char;
			my $snpval = $char{$minorsnp};
			next column unless $snpval>1;
			(my $gap) = grep {/\-/} keys %char;
			next column if $gap;
			next column if $column =~ /N/;

	 	if (scalar keys %char>1) {
	 		push @colcount, $columncounter;
			$columncounter++;
	 	}
	}
 	my $loci = join ",", @{$desc_recorder{acc}};
	my $desc = $desc_recorder{desc};
	my $firstcol = shift @colcount;
	my $lastcol = pop @colcount;
	my $cols = join ",", @colcount;
	print OUT "Ortholog $locuscounter ($file),  pseudoalign cols ($firstcol - $lastcol), desc: $desc\n";
	$locuscounter++;
	@colcount = undef;
}
sub matchnum {
	my $val = shift;
	$val =~ /(\d+)/;
	$1;
}
