#!/usr/bin/perl
use lib ("/opt/rocks/lib/perl5/site_perl/5.10.1");

use Getopt::Long;

use Bio::PrimarySeq;
use Bio::SeqIO;
use Bio::Index::Fasta;
use Bio::SearchIO; 
use strict;

sub usage
{
    print "Usage: coresnp2.pl -b <blast file> -i <index> -c <strain count> -p <pid cutoff> -l <hsp length> -o <output>\n";
}

my ($blastfile,$index,$strain_count,$cutoff,$minhsplength,$output_dir);

GetOptions('b|blast-file=s' => \$blastfile,
           'i|index=s' => \$index,
           'c|strain-count=i' => \$strain_count,
           'p|pid-cutoff=f' => \$cutoff,
           'l|hsp-length=i' => \$minhsplength,
           'o|output_dir=s' => \$output_dir) or die "Invalid options";

die "Invalid blast file\n".usage if (not defined $blastfile or not -e $blastfile);
die "Invalid index\n".usage if (not -e $index);
die "Invalid strain-count\n".usage if (not defined $strain_count or $strain_count <= 0);
die "Invalid pid-cutoff\n".usage if (not defined $cutoff or $cutoff < 0 or $cutoff > 100);

my %hit_recorder;
my %pid_recorder;
my $inx = Bio::Index::Fasta->new( -filename => $index);
my $in = new Bio::SearchIO(-format => 'blast', 
                           -file   => $blastfile);
my %revcom_recorder;
$| = 1; # flush after every write/print
query: while( my $result = $in->next_result ) {
  print ".";
  ## $result is a Bio::Search::Result::ResultI compliant object
  hit: while( my $hit = $result->next_hit ) {

      my $query_length = $hit->query_length;
      # next query unless $query_length>400; #minimum 100aa proteins	

      my $hit_length = $hit->length;
      # next hit unless $hit_length/$query_length > 1.2 or $hit_length/$query_length < 0.8; # both have to be larger than 100aa

      my $smaller_seq= $query_length<$hit_length?$query_length:$hit_length;

      ## $hit is a Bio::Search::Hit::HitI compliant object
      while( my $hsp = $hit->next_hsp ) {
		 next unless $hsp->hsp_length>$minhsplength;
	
	## $hsp is a Bio::Search::HSP::HSPI compliant object
	if( $smaller_seq / $hsp->length('total') > $cutoff / 100 ) {
	# added by gvd get rid of 100% stuff
        #  next if $smaller_seq / $hsp->length('total') == 1;
	#  next if $hsp->percent_identity==100;
	  if ( $hsp->percent_identity >= $cutoff ) {

	    my $hitname = $hit->name;
	    my (@elem) = split /\|/, $hitname;
	    
	    my $strain = $elem[0];
	    next hit if $hit_recorder{$result->query_name}{$strain};
	    $hit_recorder{$result->query_name}{$strain}=$hit->name;
		push @{$pid_recorder{$result->query_name}}, $hsp->percent_identity;
            # print "$strain\n";
	    #         print "Query=",   $result->query_name,
		$revcom_recorder{$result->query_name}{$strain} = [$hsp->query->frame, $hsp->hit->frame]; 
	  }
        }
      }
    }
  }
print "\ngrabbing results\n";
my %bigseq;
my $filecounter = 1;
# work through hit recorder
my @query_loci = keys %hit_recorder;
my @master_strains;
for my $query (@query_loci) {
    my @strains = keys %{$hit_recorder{$query}};
    @master_strains = @strains;
    #added by gvd
   (my $smallest_pid) = sort {$a <=> $b} @{$pid_recorder{$query}};
my $ids = join " ", @{$pid_recorder{$query}};
    next unless $smallest_pid <100;
    next unless @strains ==$strain_count;
my $out_file_path = (defined $output_dir) ? "$output_dir/core.$query.ffn" : "core.$query.ffn";
my $out = new Bio::SeqIO(-file=>">$out_file_path", -format=>"fasta");
$filecounter++;

    # grab the sequences using the accessions
    for my $strain (@strains) {
#	my $out = new Bio::SeqIO(-file=>">>core.$strain.faa", -format=>"fasta");
	my $hitname = $hit_recorder{$query}{$strain};
	my $seq = $inx->fetch($hitname);
	my $newdesc = $seq->display_id ; $newdesc .= " [$strain] "; $newdesc .= $seq->desc;
	$seq->desc($newdesc);
	$seq->display_id($strain);
	$bigseq{$strain}.= $seq->seq;
	my @frame = @{$revcom_recorder{$query}{$strain}};
	if ($frame[0] * $frame[1] < 0 ) {
	$seq = $seq->revcom;
	print "revcom in $query $strain\n"; 
	}
	$out->write_seq($seq);
    }
}

