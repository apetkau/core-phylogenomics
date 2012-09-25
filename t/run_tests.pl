#!/usr/bin/env perl

use warnings;
use strict;

use TAP::Harness;

my $harness = TAP::Harness->new;

my $aggregator = $harness->runtests(['pseudoalign.t'],
				    ['snp_matrix.t'],
				    ['pipeline_blast.t'],
				    ['pipeline_ortho.t'],
		   );

$harness->summary($aggregator);
