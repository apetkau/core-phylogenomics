#!/usr/bin/perl

package Logger;

use strict;
use warnings;

sub new
{
	my ($class, $log_dir, $verbose) = @_;

	my $self = {};
	bless($self,$class);

	$self->{'_verbose'} = $verbose;
	$self->{'_log_dir'} = $log_dir;

	my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = localtime(time);
	$mon +=1;
	$year += 1900;
	my $main_log = sprintf("$log_dir/pipeline.%02d.%02d.%02d-%02d.%02d.%02d.log",$year,$mon,$mday,$hour,$min,$sec);
	open(my $main_log_h, ">$main_log") or die "Could not open main log file $main_log: $!";
	$self->{'_main_log_h'} = $main_log_h;

	return $self;
}

sub log($$)
{
	my ($self,$message,$level) = @_;
	my $verbose = $self->{'verbose'};
	my $main_log_h = $self->{'_main_log_h'};

	$verbose = 0 if (not defined $verbose);
	print $message if ($level <= $verbose);
	print $main_log_h $message if (defined $main_log_h);
}

1;
