#!/usr/bin/env perl

# run_assembly_trimClean: trim and clean a set of raw reads
# Author: Lee Katz <lkatz@cdc.gov>
# Modified by Aaron Petkau <aaron.petkau@phac-aspc.gc.ca> on October 3, 2012
# TODO read .gz files
# TODO output .gz files

package PipelineRunner;
my ($VERSION) = ('$Id: $' =~ /,v\s+(\d+\S+)/o);

my $settings = {
    appname => 'cgpipeline',
};
my $stats;

use strict;
use FindBin;
use lib "$FindBin::RealBin/../lib";
$ENV{PATH} = "$FindBin::RealBin:".$ENV{PATH};

use Getopt::Long;
use File::Temp ('tempdir');
use File::Path;
use File::Spec;
use File::Copy;
use File::Basename;
use List::Util qw(min max sum shuffle);
use POSIX;
#use Math::Round qw/nearest/;

use Data::Dumper;
use threads;
use Thread::Queue;
use threads::shared;

$0 = fileparse($0);
local $SIG{'__DIE__'} = sub { my $e = $_[0]; $e =~ s/(at [^\s]+? line \d+\.$)/\nStopped $1/; die("$0: ".(caller(1))[3].": ".$e); };
sub logmsg {print STDOUT "$0: ".(caller(1))[3].": @_\n";}

my %threadStatus:shared;
my @IOextensions=qw(.fastq .fastq.gz .fq);

exit(main());

sub main() {
  my $settings={
    numcpus=>getNumCPUs(),
    #poly=>1, # number of reads per group (1=SE, 2=paired end)
    qualOffset=>33,
    # trimming
    min_quality=>35,
    bases_to_trim=>20, # max number of bases that will be trimmed on either side
    # cleaning
    min_avg_quality=>30,
    min_length=>62,# twice kmer length sounds good
  };
  
  GetOptions($settings,qw(numcpus=i poly=i infile=s@ outfile=s min_quality=i bases_to_trim=i min_avg_quality=i  min_length=i quieter notrim debug));
  
  my $infile=$$settings{infile} or die "Error: need an infile\n".usage($settings);
  my $outfile=$$settings{outfile} or die "Error: need an outfile\n".usage($settings);
  
  my $outfileDir;
  ($$settings{outBasename},$outfileDir,$$settings{outSuffix}) = fileparse($outfile,@IOextensions);
  my $singletonOutfile="$outfileDir/$$settings{outBasename}.singletons$$settings{outSuffix}";

  my $printQueue=Thread::Queue->new;
  my $singletonPrintQueue=Thread::Queue->new;
  my $printThread=threads->new(\&printWorker,$outfile,$printQueue,$settings);
  my $singletonPrintThread=threads->new(\&singletonPrintWorker,$singletonOutfile,$singletonPrintQueue,$settings);
  
  my $entryCount=qualityTrimFastqPoly($infile,$printQueue,$singletonPrintQueue,$settings);
  
  $singletonPrintQueue->enqueue(undef); # term signal
  $singletonPrintThread->join;
  $printQueue->enqueue(undef); # term signal
  $printThread->join;
  
  my $numGood=sum(values(%threadStatus));
  my $freq_isClean=$numGood/$entryCount;
  $freq_isClean=nearest(0.01,$freq_isClean);
  logmsg "\nFinished! $freq_isClean pass rate.";

  return 0;
}

# returns a reference to an array of fastq entries.
# These entries are each a string of the actual entry
sub qualityTrimFastqPoly($;$){
  my($fastq,$printQueue,$singletonQueue,$settings)=@_;
  my $verbose=!$$settings{quieter};
  my $reportEvery=1000000;
    $reportEvery=1000 if($$settings{debug});

  # TODO check for poly with each fastq file
  my $poly=$$settings{poly}||checkPolyness($$fastq[0],$settings);
  $poly=1 if($poly<1); #sanity check
  $$settings{poly}=$poly; # this line is a band-aid until I pass the parameter directly the workers later
  
  # initialize the threads
  my (@t,$t);
  my $Q=Thread::Queue->new;
  for(0..$$settings{numcpus}-1){
    $t[$t++]=threads->create(\&trimCleanPolyWorker,$Q,$printQueue,$singletonQueue,$settings);
  }

  my $entryCount=0;
  my @fastq=@$fastq;
  for my $fastq (@fastq){

    logmsg "Trimming and cleaning a file $fastq with poly=$poly";
  
    # check the file before continuing
    my $readsToCheck=5;
    my $warnings=checkFirstXReads($fastq,$readsToCheck,$settings);
    warn "WARNING: There were $warnings warnings. Judging from the first $readsToCheck reads, it is possible that many or all sequences will be filtered out." if($warnings);

    # load all reads into the threads for analysis
    my $linesPerGroup=4*$poly;
    my $moreLinesPerGroup=$linesPerGroup-1; # calculate that outside the loop to save CPU
    if($$settings{inSuffix}=~/\.fastq$/){
      open(FQ,'<',$fastq) or die "Could not open $fastq for reading: $!";
    }
    elsif($$settings{inSuffix}=~/\.fastq\.gz/){
      open(FQ,"gunzip -c $fastq | ") or die "Could not open $fastq for reading: $!";
    }
    else{
      die "Could not determine the file type for reading based on your extension $$settings{inSuffix}";
    }
    while(1){
      # get a whole array of entries before enqueuing because it is a slow step
      my @entry;
      for(1..ceil($reportEvery/10)){
        $entryCount++;
        my $entry;
        $entry .=<FQ> for(1..$linesPerGroup); # e.g. 8 lines total for paired end entry
        last if(!$entry);
        push(@entry,$entry);
      }
      last if(!@entry);
        
      $Q->enqueue(@entry);

      # pause if/while there's too much in memory
      while($Q->pending > $reportEvery*$$settings{numcpus}){
        sleep 2;
      }

      if($entryCount%$reportEvery==0 && $verbose){
        my $numGood=sum(values(%threadStatus));
        my $freq_isClean=$numGood/($entryCount-$Q->pending);
        $freq_isClean=nearest(0.01,$freq_isClean);
        logmsg "Finished loading $entryCount pairs or singletons ($freq_isClean pass rate).";
        if($$settings{debug}){
          logmsg "DEBUG";
          last;
        }
      }
    }
    close FQ;
  }
  logmsg "Done loading: $entryCount entries loaded.";
  
  # stop the threads
  $Q->enqueue(undef) for(1..$$settings{numcpus});
  queue_status_updater($Q,$entryCount,$settings);

  # grab all the results from the threads
  for(@t){
    my $tmp=$_->join;
  }
  return $entryCount;
}

sub trimCleanPolyWorker{
  my($Q,$printQueue,$singletonQueue,$settings)=@_;
  my $poly=$$settings{poly};
  my $notrim=$$settings{notrim};
  my $tid="TID".threads->tid;
  my(@entryOut);
  ENTRY:
  while(defined(my $entry=$Q->dequeue)){
    my $is_singleton=0; # this entry is not a set of singletons until proven otherwise
    my @read;
    my @entryLine=split(/\s*\n\s*/,$entry);
    for my $i (0..$poly-1){
      my $t={};
      ($$t{id},$$t{seq},undef,$$t{qual})=splice(@entryLine,0,4);
      trimRead($t,$settings) if(!$notrim);
      $is_singleton=1 if(!read_is_good($t,$settings));
      $read[$i]=$t;
    }
    
    # see if these are singletons, and if so, add them to the singleton queue
    if($is_singleton){
      my @singleton;
      for my $read (@read){
        next if(!read_is_good($read,$settings));
        my $singletonOut="$$read{id}\n$$read{seq}\n+\n$$read{qual}\n";
        $singletonQueue->enqueue($singletonOut);
        $threadStatus{$tid}+=1/$poly;
      }
      # If these are singletons then they cannot be printed to the paired end output file. 
      # Move onto the next entry.
      next ENTRY; 
    }
    
    $threadStatus{$tid}++;
    my $entryOut="";
    for my $read (@read){
      $entryOut.="$$read{id}\n$$read{seq}\n+\n$$read{qual}\n";
    }
    $printQueue->enqueue($entryOut);
  }
  #return \@entryOut;
}

sub printWorker{
  my($outfile,$Q,$settings)=@_;
  if($$settings{outSuffix}=~/\.fastq$/){
    open(OUT,">",$outfile) or die "Error: could not open $outfile for writing because $!";
  }
  elsif($$settings{outSuffix}=~/\.fastq\.gz/){
    open (OUT, "| gzip -c > $outfile") or die "Error: could not open $outfile for writing because $!";
  }
  else{
    die "Could not determine the file type for writing based on your extension $$settings{outSuffix}";
  }
  while(defined(my $line=$Q->dequeue)){
    print OUT $line;
  }
  close OUT;
  logmsg "Reads are in $outfile";
}
sub singletonPrintWorker{
  my($outfile,$Q,$settings)=@_;
  if($$settings{outSuffix}=~/\.fastq$/){
    open(OUT,">",$outfile) or die "Error: could not open $outfile for writing because $!";
  }
  elsif($$settings{outSuffix}=~/\.fastq\.gz/){
    open (OUT, "| gzip -c > $outfile") or die "Error: could not open $outfile for writing because $!";
  }
  else{
    die "Could not determine the file type for writing based on your extension $$settings{outSuffix}";
  }
  while(defined(my $line=$Q->dequeue)){
    print OUT $line;
  }
  close OUT;
  logmsg "Singleton reads are in $outfile";
}

# Trim a read using the trimming options
# The read is a hash of id, sequence, and qual
# Note: I think I mixed up 3 and 5?  Ugh.  Whatever.
sub trimRead{
  my($read,$settings)=@_;
  # TODO just kill off this read right away if it is less than the min_length, to save on time
  my($numToTrim3,$numToTrim5,@qual)=(0,0,);
  @qual=map(ord($_)-$$settings{qualOffset},split(//,$$read{qual}));
  for(my $i=0;$i<$$settings{bases_to_trim};$i++){
    $numToTrim5++ if(sum(@qual[0..$i])/($i+1)<$$settings{min_quality});
    #last if($qual[$i]>=$$settings{min_quality});
  }
  #for(my $i=$$read{length}-$$settings{bases_to_trim};$i<@qual;$i++){
  for(my $i=0;$i<$$settings{bases_to_trim};$i++){
    my $pos=$$read{length}-$i;
    $numToTrim3++ if(sum(@qual[$pos..$#qual])/($i+1)<$$settings{min_quality});
    #last if($qual[$i]>=$$settings{min_quality});
  }
  if($numToTrim3 || $numToTrim5){
    #my $tmp= "TRIM  ==>$numToTrim5 ... $numToTrim3<==\n  >$$read{seq}<\n   $$read{qual}";
    $$read{seq}=substr($$read{seq},$numToTrim5,$$read{length}-$numToTrim5-$numToTrim3);
    $$read{qual}=substr($$read{qual},$numToTrim5,$$read{length}-$numToTrim5-$numToTrim3);
    #print "$tmp\n  >$$read{seq}<\n\n";
  }
}

# Deterimine if a single read is good or bad (0 or 1)
# judging by the cleaning options
sub read_is_good{
  my($read,$settings)=@_;
  my $readLength=length($$read{seq});
  #die "short read: $$read{seq}\n$readLength < $$settings{min_length}\n" if($readLength<$$settings{min_length});
  return 0 if($readLength<$$settings{min_length});
  
  # avg quality
  my $qual_is_good=1;
  my @qual=map(ord($_)-$$settings{qualOffset},split(//,$$read{qual}));
  my $avgQual=sum(@qual)/$readLength;
  return 0 if($avgQual<$$settings{min_avg_quality});
  return 1;
}

sub queue_status_updater{
  my($Q,$entryCount,$settings)=@_;
  STATUS_UPDATE:
  while(my $p=$Q->pending){
    my $numGood=sum(values(%threadStatus));
    my $freq_isClean=$numGood/($entryCount-$Q->pending);
    $freq_isClean=nearest(0.01,$freq_isClean);
    logmsg "$p entries left to process. $freq_isClean pass rate.";
    # shave off some time if the queue empties while we are sleeping
    for(1..30){
      sleep 2;
      last STATUS_UPDATE if(!$Q->pending);
    }

  }
  return 1;
}

# TODO use this subroutine to find out if this is a paired-end file and set the default poly=X
sub checkFirstXReads{
  my($infile,$numReads,$settings)=@_;

  (undef,undef,$$settings{inSuffix}) = fileparse($infile,@IOextensions);

  my $warning=0;
  die "Could not find the input file $infile" if(!-e $infile);
  if(-s $infile < 1000){
    warn "Warning: Your input file is pretty small";
    $warning++;
  }

  # figure out if the min_length is larger than any of the first X reads.
  # If so, spit out a warning. Do not change the value. The user should be allowed to make a mistake.
  logmsg "Checking minimum sequence length param on the first 5 sequences.";
  if($$settings{inSuffix}=~/\.fastq$/){
    open(IN,'<',$infile) or die "Could not open $infile for reading: $!";
  }
  elsif($$settings{inSuffix}=~/\.fastq\.gz/){
    open(IN,"gunzip -c $infile | ") or die "Could not open $infile for reading: $!";
  }
  else{
    die "Could not determine the file type for reading based on your extension $$settings{inSuffix}";
  }
  my $i=1;
  while(my $line=<IN>){
    $line.=<IN> for (1..3);
    my ($id,$sequence)=(split("\n",$line))[0,1];
    my $length=length($sequence);
    if($length<$$settings{min_length}){
      warn "WARNING: Read $id has length less than the minimum sequence length $$settings{min_length}.\n" if(!$$settings{quieter});
      $warning++;
    }
    last if($i++>=$numReads);
  }
  close IN;
  return $warning;
}

################
## utility
################

# returns 1 for SE, 2 for PE, and -1 is for internal error
sub checkPolyness{
  my ($infile,$settings)=@_;
  eval{
    require AKUtils;
  };
  if($@){
    warn "WARNING: I could not understand if the file is paired end.  I will assume not.";
    return 1;
  }

  my $poly=AKUtils::is_fastqPE($infile,{checkFirst=>20});
  $poly++;

  return $poly;
}

# until I find a better way to round
sub nearest{
  my ($nearestNumber,$num)=@_;
  $num=floor(($num+0.00)*100)/100;
  $num=sprintf("%.2f",$num);
  return $num;
}

sub getNumCPUs() {
  my $num_cpus;
  open(IN, '<', '/proc/cpuinfo'); while (<IN>) { /processor\s*\:\s*\d+/ or next; $num_cpus++; } close IN;
  return $num_cpus || 1;
}

sub usage{
  my ($settings)=@_;
  "trim and clean a set of raw reads
  Usage: $0 -i reads.fastq -o reads.filteredCleaned.fastq [-p 2]
    -i input file in fastq format
    -o output file in fastq format
  Additional options
  
  -p 1 or 2 (p for poly)
    1 for SE, 2 for paired end (PE). 0 for automatic detection (default)
  -q for somewhat quiet mode (use 1>/dev/null for totally quiet)
  --notrim to skip trimming of the reads. Useful for assemblers that require equal read lengths.
  --numcpus [number]: sets maximum number of cpus/threads to use for trim/cleaning. Defaults to number of cores on machine.

  Use phred scores (e.g. 20 or 30) or length in base pairs if it says P or L, respectively
  --min_quality P             # trimming
    default: $$settings{min_quality}
  --bases_to_trim L           # trimming
    default: $$settings{bases_to_trim}
  --min_avg_quality P         # cleaning
    default: $$settings{min_avg_quality}
  --min_length L              # cleaning
    default: $$settings{min_length}
  "
}


