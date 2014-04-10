#!/usr/bin/env perl
use strict;
use Bio::AlignIO;
use Bio::SimpleAlign;
use Bio::LocatableSeq;
use Bio::SeqIO;
use File::Basename qw(basename);
use File::Copy;
use Getopt::Long;

sub usage
{
    print "Usage: ".basename($0)."[Options]\n";
    print "Options:\n";
    print "\t--input-trimmed:  The input directory for the trimmed files\n";
    print "\t--input-sequence:  The input directory for the sequence files\n";
    print "\t--strain-id: (Optional) The strain id for the report\n";
    print "Example:\n";
    print "\t".basename($0)." --input-trimmed data/align --input-sequence data/core\n";
}

my $columncounter=1;

my $strain_id_opt;
my $input_dir_seq_opt;
my $input_dir_trimmed_opt;
if (!GetOptions('strain-id|s=s' => \$strain_id_opt,
                'input-trimmed=s' => \$input_dir_trimmed_opt,
                'input-sequence=s' => \$input_dir_seq_opt))
{
    usage;
    exit 1;
}

my $input_dir_seq;
my $input_dir_trimmed;
my $strainid = $strain_id_opt;
if (not defined $input_dir_seq_opt or not (-d $input_dir_seq_opt))
{
    print STDERR "Invalid input sequence directory";
    usage;
    exit 1;
}
else
{
    $input_dir_seq = $input_dir_seq_opt;
}

if (not defined $input_dir_trimmed_opt or not (-d $input_dir_trimmed_opt))
{
    print STDERR "Invalid input trimmed directory";
    usage;
    exit 1;
}
else
{
    $input_dir_trimmed = $input_dir_trimmed_opt;
}

opendir (DH, $input_dir_trimmed);
my @files = sort {&matchnum($a) <=> &matchnum($b)} grep { /trimmed$/i } readdir(DH);
my @columns;
my %longseq;
open (OUT, ">locusreport.txt");
my $locuscounter = 1;
for my $file (@files) {
	my $in = new Bio::AlignIO(-file=>"$input_dir_trimmed/$file", -format=>"clustalw",-longid=>1);
	$in->interleaved(0);
    $file =~ /(.*?)\.aln.trimmed$/;
	my $seqin = new Bio::SeqIO(-file=>"$input_dir_seq/$1",-format=>"fasta");
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
