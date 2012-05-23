#!/usr/bin/perl
use strict;
use Bio::AlignIO;
use Bio::SimpleAlign;
use Bio::LocatableSeq;
use Cwd;
my $outputreport = "snp.matrix.txt";
my $in =  new Bio::AlignIO(-file=>$ARGV[0], -format=>"phylip");
my $aln = $in->next_aln;
my %longseq;
my @columns;
for my $seq ($aln->each_alphabetically) {
    my @nucleotides = split //, $seq->seq;
    $longseq{$seq->display_id} .= $seq->seq;
    $longseq{$seq->display_id} .= "*";
}

my @accessions = sort {$a cmp $b } keys %longseq;
for my $acc (sort {$a cmp $b } keys %longseq) {
    my @chars  = split undef, $longseq{$acc};
    for (my $x=0;$x<@chars;$x++) {
	$columns[$x] .= $chars[$x];
    }   
}
my %matrix;
my $accsorter;
column: for my $column (@columns) {
    my %strain;
    my @chars = split undef, $column;
    my @accessions = sort {$a cmp $b } keys %longseq;
    for my $char (@chars) {
	my $accession = shift @accessions;
	push @{$strain{$char}}, $accession;
	
    }
    if (scalar (keys %strain)>2){ 
	warn "whoa, \"$column\" has too many snps!\n"; 
    }  
    if (scalar (keys %strain)<2){ 
	warn "whoa, \"$column\" has too few snps!\n"; 
	next column;
    }
    
    my @nucleotides  = keys %strain;
    my %seen;
    for my $snp1 (@nucleotides) {
	snp2: for my $snp2 (@nucleotides) {
	    next snp2 if $snp1 eq $snp2; 
	    next snp2 if $seen{$snp1}{$snp2};
	    next snp2 if $seen{$snp2}{$snp1};
	    $seen{$snp1}{$snp2}++;
	    $seen{$snp2}{$snp1}++;
	    my @group1 = @{$strain{$snp1}};
	    my @group2 = @{$strain{$snp2}};
	    for my $acc1 (@group1) {
		for my $acc2 (@group2) {
		    $matrix{$acc1}{$acc2}++;
		    $matrix{$acc2}{$acc1}++;	
	}
	    }
	}
    }
}
use Data::Dumper;
my %accsorter;
my %sortseen;
# sort the accessions by values, by inverting the keys, and values
for my $accession1 (@accessions) {
	for my $accession2 (@accessions) {
		push @{$accsorter{$matrix{$accession1}{$accession2}}}, [$accession1, $accession2] unless  $sortseen{$accession2}{$accession1};
		$sortseen{$accession1}{$accession2}++;	
	}
}
my %accounter; map {$accounter{$_}++} @accessions;
my @sortedaccs;
for my $val (sort {$b <=> $a } keys %accsorter) {
	last unless keys %accounter;
	my @acclist = @{$accsorter{$val}};
	for my $accs_r (@acclist) {
		my @accs = @$accs_r;
		for my $acc (@accs) {
			if ($accounter{$acc}) {
				push @sortedaccs, $acc;
				delete $accounter{$acc};
			}	               
		}
	}
}
# print Dumper \%accsorter; exit;
print join "\t","strain",@sortedaccs, "\n";
for my $acc1 (@sortedaccs)  {
    push my @row, $acc1?$acc1:"0";
    for my $acc2 (@sortedaccs) {
	push @row, $matrix{$acc1}{$acc2}?$matrix{$acc1}{$acc2}:"0";
    }
    print join "\t", @row, "\n";
}

