#!/usr/bin/perl
use strict;
use lib ("/opt/rocks/lib/perl5/site_perl/5.10.1");
use Bio::AlignIO;
use Bio::SimpleAlign;
use Cwd;
use File::Copy;
my $input_dir = shift;
my $output_dir = shift; 

$input_dir = getcwd if (not defined $input_dir);
$output_dir = $input_dir if (not defined $output_dir);

opendir (my $input_dh, $input_dir) or die "Could not open $input_dir: $!";
my @ids = sort {$a <=> $b } map {/(\d+)/;$1} grep {/snps\d+\.aln/} readdir($input_dh);
close($input_dh);

locus: for my $locusid (@ids) {
	my $alignfile = "$input_dir/snps" . $locusid . ".aln";
        my $alignfile_out = "$output_dir/snps${locusid}.aln.trimmed";
	print "$alignfile\n";
        my $in = Bio::AlignIO->new(-file =>$alignfile, -format=>"clustalw");
	my $aln = $in->next_aln;
#	my $qualfile = "quals". $locusid . ".aln";
#	open QUAL , $qualfile || die "Foo! Qualfile $qualfile: $!\n";
#	my @quals = <QUAL>;
#	my %qualmap;
#	for my $row (@quals) {
#		my @quals = split /\s+/, $row;
#	    my $strain = shift @quals;
#	    $qualmap{$strain} = \@quals;
#	}

	my @starts;
	my @ends;
	my $start;
	my $end;
	for my $seq ($aln->each_alphabetically) {
		my $seqstr = $seq->seq;
		$seqstr =~ /(^\-{0,}).*?(\-{0,}$)/;
		push @starts, length ($1)+5;
		push @ends, $seq->length - length ($2) -5; # for good measure
	}
	@starts = sort {$b <=> $a} @starts; # largest number in pos 0
	@ends = sort {$a <=> $b} @ends; # smallest number in pos 0
	$start = shift @starts;
	$end = shift @ends;
	next locus unless $start < $end;
	my $newalign = new Bio::SimpleAlign;
	my $counter = 1;
#	open QUAL, ">quals" . $locusid . ".aln.trimmed";
	for my $seq ($aln->each_alphabetically) {
    	# trim the alignments
    	my $newstr = $seq->subseq($start, $end);
		$seq->seq($newstr);
		$seq->end(length( $newstr) - scalar (@{[$newstr =~ /(-)/g]}));
		$newalign->add_seq($seq);		
#		my @quals = @{$qualmap{$seq->display_id}};
#		my @trimquals = @quals[$start..$end -1];
#		my $newqualline = join " ", $seq->display_id, @trimquals, "\n";
#		print QUAL $newqualline;
	}
#	close QUAL;
	new Bio::AlignIO(-file=>">$alignfile_out", -format=>"clustalw")->write_aln($newalign);
}
