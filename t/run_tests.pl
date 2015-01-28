#!/usr/bin/env perl

use warnings;
use strict;

use TAP::Harness;
use Getopt::Long;
use FindBin;

my $script_dir = $FindBin::Bin;

sub usage
{
        return "Usage: $0 --tmp-dir [tmp_directory] [--keep-tmp]\n";
}

### MAIN ###

my $tmp_dir;

my $keep_tmp;
if (not GetOptions('t|tmp-dir=s' => \$tmp_dir,
		   'k|keep-tmp' => \$keep_tmp))
{
        die usage;
}

die "no tmp-dir defined\n".usage if (not defined $tmp_dir);
die "tmp-dir does not exist\n".usage if (not (-e $tmp_dir));

$keep_tmp = 0 if (not defined $keep_tmp);

# alias => args
my %args;
if ($keep_tmp)
{
	%args = ('pipeline_blast' => ['--tmp-dir', $tmp_dir, '--keep-tmp'],
		    'pipeline_ortho' => ['--tmp-dir', $tmp_dir, '--keep-tmp'],
		    'pipeline_mapping' => ['--tmp-dir', $tmp_dir, '--keep-tmp'],
		    'pipeline_preparefastq' => ['--tmp-dir', $tmp_dir, '--keep-tmp'],
		    'copy_input_fastq' => ['--tmp-dir', $tmp_dir, '--keep-tmp']);
}
else
{
	%args = ('pipeline_blast' => ['--tmp-dir', $tmp_dir],
		    'pipeline_ortho' => ['--tmp-dir', $tmp_dir],
		    'pipeline_mapping' => ['--tmp-dir', $tmp_dir],
		    'pipeline_preparefastq' => ['--tmp-dir', $tmp_dir],
		    'copy_input_fastq' => ['--tmp-dir', $tmp_dir]);
}


$args{'pseudoalign'} = [];
$args{'snp_matrix'} = [];
$args{'variant_calls'} = [];

#if ($keep_tmp)
#{
#	push(@{$args{'pipelin_blast')}},'--keep-tmp');
#	push(@{$args{'pipelin_ortho')}},'--keep-tmp');
#	push(@{$args{'pipeline_mapping')}},'--keep-tmp');
#	push(@{$args{'pipeline_preparefastq')}},'--keep-tmp');
#}

my $harness = TAP::Harness->new({'test_args' => \%args});

my $aggregator = $harness->runtests(["$script_dir/pseudoalign.t", 'pseudoalign'],
				    ["$script_dir/snp_matrix.t", 'snp_matrix'],
				    ["$script_dir/../lib/vcf2pseudoalignment/t/variant_calls.t", 'variant_calls'],
				    ["$script_dir/pipeline_blast.t", 'pipeline_blast'],
				    ["$script_dir/pipeline_ortho.t", 'pipeline_ortho'],
				    ["$script_dir/pipeline_mapping.t", 'pipeline_mapping'],
				    ["$script_dir/pipeline_preparefastq.t", 'pipeline_preparefastq'],
				    ["$script_dir/copy_input_fastq.t", 'copy_input_fastq']
		   );

