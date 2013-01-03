#!/usr/bin/env perl

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

	my $time_string = GetLogDirTime(time);
	my $main_log = "$log_dir/pipeline.log";
	open(my $main_log_h, ">$main_log") or die "Could not open main log file $main_log: $!";
	$self->{'_main_log_h'} = $main_log_h;

	return $self;
}

sub GetLogDirTime
{
	my ($time) = @_;

	my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = localtime($time);
	$mon +=1;
	$year += 1900;
	return sprintf("%02d.%02d.%02d-%02d.%02d.%02d",$year,$mon,$mday,$hour,$min,$sec);
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
