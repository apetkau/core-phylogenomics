#!/usr/bin/env perl
use strict;
use Bio::SeqIO;
use Bio::AlignIO;
use Bio::Index::Qual;
my $index = Bio::Index::Qual->new(-filename=>"vc.qual.idx");
open LOCUS, "locusmap.txt" ||  die "no locusmap.txt :( $!\n";
my @rows = <LOCUS>; 
close LOCUS;
my %locusmap;
for my $row (@rows) {
	my ($fileid, $loci) = split /\:\s/, $row;
	my @loci = split /\s+/, $loci;
	$locusmap{$fileid} = \@loci;
}
my @files = <snps*.aln>;
@files = grep {/snps\d+\.aln/} @files;
for my $file (@files) {
	my ($id) = $file =~ /(\d+)/;
	my $newqualfile = "quals$id.aln";
	open QUAL, ">$newqualfile" || die "no open $newqualfile: $!\n";
 	my $alnin = new Bio::AlignIO(-file=>$file, -format=>"clustalw",-longid=>1);
	my $aln = $alnin->next_aln;
	# get each locus id from each strain in the file and get the quality info from it, then align it.
	my @loci = @{$locusmap{$id}};
	for my $locus (@loci) {
		#locus looks like strain|locusid
		my ($strain, $locusid) = split /\|/, $locus;
		# get the quality file
		my $qualseq = $index->fetch($locus);
        my $alnseq = $aln->get_seq_by_id($strain);	
		die "couldnt retrieve $locus\n" unless $qualseq;
		die "couldn't retrieve $strain\n" unless $strain;
		my @bases = split //, $alnseq->seq;
		my @quals = @{$qualseq->qual};
		my @newquals;
		for my $base (@bases) {
			if ($base eq "-") {
				push @newquals, "-"
			}
			else {
				push @newquals, shift @quals;
			}
		}
		my $newquals = join " ", $strain, @newquals;
		print QUAL $newquals,"\n";	
	}
	close QUAL;
}

