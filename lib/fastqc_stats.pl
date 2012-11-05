#!/usr/bin/env perl

use warnings;
use strict;

my $usage = "Usage: $0 [strain name] [fastq file] [fastqc_dir] [genome length] [out file]\n";

my $strain_name = $ARGV[0];
my $fastq_file = $ARGV[1];
my $fastqc_dir = $ARGV[2];
my $genome_length = $ARGV[3];
my $out_file = $ARGV[4];

die "strain_name not defined\n$usage" if (not defined $strain_name);

die "fastq_file not defined\n$usage" if (not defined $fastq_file);
die "fastq_file=$fastq_file does not exist\n$usage" if (not -e $fastq_file);

die "fastqc_dir not defined\n$usage" if (not defined $fastqc_dir);
die "fastqc_dir=$fastqc_dir is not a directory\n$usage" if (not -d $fastqc_dir);

die "genome_length not defined\n$usage" if (not defined $genome_length);
die "genome_length=$genome_length not a valid number\n$usage" if ($genome_length !~ /^\d+/);
die "genome_length cannot be 0\n$usage" if ($genome_length <= 0);

die "out file not defined" if (not defined $out_file);

open(my $out_h,">$out_file") or die "Could not open $out_file for writing: $!";

my $data = "$fastqc_dir/fastqc_data.txt";
my $summary = "$fastqc_dir/summary.txt";

# check for pass
my $pass = 1;
my $line;
my $fh;
open($fh, "<$summary") or die "Could not open $summary: $!";
while($pass and ($line = readline($fh)))
{
	$pass = 0 if ($line =~ /^FAIL/);
}
close($fh);

# fill in modules_table with lines from each module/section
open($fh, "<$data") or die "Could not open $data: $!";
my $in_module = 0;
my %modules_table;
my $mod_name;
my $status;
my $lines = [];
while($line = readline($fh))
{
	chomp $line;
	if ($line =~ /^>>([^\t]*)/)
	{
		my $module_header = $1;
		if ($module_header =~ /^END_MODULE/)
		{
			if ($in_module)
			{
				$modules_table{$mod_name} = [$status,$lines];
				$lines = [];
				$mod_name = '';
				$in_module = 0;
				$status = '';
			}
			else
			{
				die "Got line '$line' when not in module";
			}
		}
		else
		{
			if ($line =~ /^>>([^\t]*)\t([^\t]*)/)
			{
				$status = $2;
			}

			$mod_name = $module_header;
			$in_module = 1;
		}
	}
	elsif (not $in_module)
	{
		#warn "line='$line' and not in module";
	}
	else
	{
		push(@$lines,$line);
	}
}

# get number of sequences
my $total_seq;
my $failed_on = '';
my $duplicate_percentage = '-1';
my $seq_length;
my $encoding;
for my $key (keys %modules_table)
{
	my @properties = @{$modules_table{$key}};
	my $status = $properties[0];
	if ($status eq 'fail')
	{
		if ($failed_on ne '')
		{
			$failed_on .= ','.$key;
		}
		else
		{
			$failed_on .= $key;
		}
	}

	if ($key eq 'Basic Statistics')
	{
		my @lines = @{$properties[1]};
		for $line (@lines)
		{
			if ($line =~ /^Total\s+Sequences\s+(\d+)/)
			{
				$total_seq = $1;
			}
			elsif ($line =~ /^Encoding\s+(.*)$/)
			{
				$encoding = $1;
			}
			elsif ($line =~ /^Sequence length\s+(\S+)/)
			{
				$seq_length = $1;
			}
		}
	}
	elsif ($key eq 'Sequence Duplication Levels')
	{
		my @lines = @{$properties[1]};
		for $line (@lines)
		{
			if ($line =~ /^#Total Duplicate Percentage\t(\d+\.?\d*)/)
			{
				$duplicate_percentage = $1;
			}
		}
	}
}

# get total bp
# below does not work for all fastqc reports, so must use alternative method
#my $total_bp = 0;
#my $cov = 0;
#@lines = @{$modules_table{'Sequence Length Distribution'}};
#for $line (@lines)
#{
#	next if ($line =~ /^#/);
	# below needs to account for numbers in form of 1.1E10
#	my ($length,$count) = ($line =~ /^(\d+)\s+(\d+\.?\d*E?\d*)$/i);
#	$total_bp += $length*$count;
#}
# use grep as this is fastest (much faster than bioperl)
#my $command="grep -A 1 '^\@' $fastq_file | grep -v '^[\@-]' | tr -d '[:space:]'|wc -c";
my $command="awk '((NR % 4) == 2)' $fastq_file | tr -d '[:space:]'|wc -c";
my $total_bp=`$command`;
chomp $total_bp;
die "invalid count of total_bp" if ($total_bp !~ /^\d+$/);
die "total_bp = 0" if ($total_bp == 0);
my $cov = $total_bp/$genome_length;

print $out_h "$strain_name\t".($pass ? 'PASS': 'FAIL')."\t$encoding\t$total_seq\t$total_bp\t$seq_length\t";
printf $out_h "%0.f\t%0.2f\t%s\n",$cov,$duplicate_percentage,$failed_on;

close($out_h);
