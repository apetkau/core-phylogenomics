#!/usr/bin/env perl

use warnings;
use strict;

use TAP::Harness;
use Getopt::Long;
use FindBin;

my $script_dir = $FindBin::Bin;

sub usage
{
        return "Usage: $0 --tmp-dir [tmp_directory]\n";
}

### MAIN ###

my $tmp_dir;

if (not GetOptions('t|tmp-dir=s' => \$tmp_dir))
{
        die usage;
}

die "no tmp-dir defined\n".usage if (not defined $tmp_dir);
die "tmp-dir does not exist\n".usage if (not (-e $tmp_dir));

# alias => args
my %args = ('pipeline_blast' => ['--tmp-dir', $tmp_dir],
	    'pipeline_ortho' => ['--tmp-dir', $tmp_dir],
	    'pipeline_mapping' => ['--tmp-dir', $tmp_dir],
	    'pseudoalign' => [],
	    'snp_matrix' => [],
	    'variant_calls' => []);

my $harness = TAP::Harness->new({'test_args' => \%args});

my $aggregator = $harness->runtests(["$script_dir/pseudoalign.t", 'pseudoalign'],
				    ["$script_dir/snp_matrix.t", 'snp_matrix'],
				    ["$script_dir/../lib/vcf2pseudoalignment/t/variant_calls.t", 'variant_calls'],
				    ["$script_dir/pipeline_blast.t", 'pipeline_blast'],
				    ["$script_dir/pipeline_ortho.t", 'pipeline_ortho'],
				    ["$script_dir/pipeline_mapping.t", 'pipeline_mapping']
		   );

