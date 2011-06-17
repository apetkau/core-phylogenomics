#!/usr/bin/perl
use strict;
use lib ("/opt/rocks/lib/perl5/site_perl/5.10.1");
use Bio::AlignIO;
use Bio::SimpleAlign;
use Bio::LocatableSeq;
use Cwd;
use File::Copy;
my $dir = getcwd;
# $dir .= "/trimmed";
# my $dir = getcwd; 
opendir (DH, $dir);
my $outputreport = "snp.report.txt";
open REPORT, ">$outputreport";
# my @files = sort {$a cmp $b} grep { /trimmed$/i } readdir(DH);

my @ids = sort {$a <=> $b } map {/(\d+)/;$1} grep {/snps\d+\.aln\.trimmed/} <snps*.aln.trimmed>;
my @files = map {my $file = "snps" . $_ . ".aln.trimmed";$file} @ids;
my @columns;
#my @qualumns;
my %longseq;
my %longqual;
my @seqlengths;
for my $locusid (@ids) {
    my $file = "snps".$locusid.".aln.trimmed"; 
	print "Working on $file\n";
#	my %qualmap;

#	my $qualfile = "quals". $locusid . ".aln.trimmed";
#	open QUAL , $qualfile || die "Foo! Qualfile $qualfile: $!\n";
#	my @quals = <QUAL>;
#	for my $row (@quals) {
#		my @quals = split /\s+/, $row;
#		my $strain = shift @quals;
#		$qualmap{$strain} = \@quals;
#	}
	my $in = new Bio::AlignIO(-file=>"$file", -format=>"clustalw");
	my $aln = $in->next_aln;
	for my $seq ($aln->each_alphabetically) {
	my @nucleotides = split //, $seq->seq;
		$longseq{$seq->display_id} .= $seq->seq;
		$longseq{$seq->display_id} .= "*";
		
#		push @{$longqual{$seq->display_id}}, @{$qualmap{$seq->display_id}}; 
#		push @{$longqual{$seq->display_id}}, "*";
	}
}

# transpose rows to columns
my @accessions = sort {$a cmp $b } keys %longseq;
for my $acc (sort {$a cmp $b } keys %longseq) {
	my @chars  = split undef, $longseq{$acc};
#	my @quals = @{$longqual{$acc}};
	for (my $x=0;$x<@chars;$x++) {
		$columns[$x] .= $chars[$x];
#		push @{$qualumns[$x]} , $quals[$x];
	}
}
# write out qualumns and columns for a check
#open COL, ">columns.txt" || die "foo columns: $!\n";
#open QUAL, ">qualumns.txt" || die "foo qualumns: $!\n";
#for my $column (@columns) {
#print COL $column, "\n";
#my @qual = @{shift @qualumns};
#print QUAL join " ", @qual, "\n";
#}
my @minors;
my @pseudoalign;
my $columncounter = 1;
my $locus = shift @files;
#open PQUAL, ">pseudoquals.txt";
my $locuscount=1;
column: for my $column (@columns) {
#	my $quals = join " " , @{shift @qualumns};
	my @chars = split undef, $column;
	my %char;
	map {$char{$_}++} @chars;

	 #dont include unless minor snp >=1 or if thereis a gap character
	my $lowest;
    (my $minorsnp) = sort{$char{$a} <=> $char{$b}} keys %char;
	my $snpval = $char{$minorsnp};
	next column unless $snpval>=1; # there must be one snp at least
 	next column if $column =~ /N/ || $column =~ /-/; # no gaps no ambiguities
	if ($column =~ /\*/) { # file separator
			$locus = shift @files;
			$locuscount++;
			next column;
	}
	if (scalar keys %char>1) { # as long as there are SNPs in the file
		
		push @pseudoalign, $column if scalar keys %char >1;	
		(my $minorsnp, my $majorsnp) = sort{$char{$a} <=> $char{$b}}  keys %char;
		my @strains;
		while ($column =~ /$minorsnp/g) {
			push @strains, $accessions[pos($column)-1];	
		}
		my $strains = join "\t", @strains;
		print REPORT "column $columncounter: $minorsnp($majorsnp) from $locus in:\t $strains\n"; 
		$columncounter++;
}
}
my @newseqs;
for my $column (@pseudoalign) {
	my @chars = split undef, $column;
	for (my $x=0;$x<@chars; $x++) {
		$newseqs[$x].= $chars[$x];
	}
}
my $pseudolength;
my @accessions = sort {$a cmp $b} keys %longseq;
my $newaln = new Bio::SimpleAlign;
for my $seqstr (@newseqs) {
	my $acc = shift @accessions;
	my $seq = new Bio::LocatableSeq;
	$seq->seq($seqstr);
	$seq->display_id($acc);
	$newaln->add_seq($seq);
	$pseudolength = length $seq->seq;
}

my $out = new Bio::AlignIO (-file=>">pseudoalign.phy", -format=>"phylip");
$out->write_aln($newaln);
print "there are ", length($pseudoalign[0]), "strains in the pseudoalignment.\n";
print "there are $pseudolength snps in the alignment\n";
print "there are $locuscount loci in the alignment\n";
