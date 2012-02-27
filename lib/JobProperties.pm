#!/usr/bin/perl

package JobProperties;

use YAML::Tiny;

use strict;
use warnings;

sub new
{
	my ($class, $script_dir) = @_;

	die "script_dir not defined" if (not defined $script_dir);
	die "script_dir $script_dir does not exist" if (not -e $script_dir);

	my $self = {};
	bless($self,$class);

	$self->{'_dirs'} = {};
	$self->{'_script_dir'} = $script_dir;
	$self->{'_properties'} = {};
	$self->{'_properties'}->{'files'} = {};
	$self->{'_properties'}->{'properties'} = {};
	$self->{'_properties'}->{'abs_dirs'} = {};

	return $self;
}

sub read_config
{
	my ($self, $config) = @_;

	if (not defined $config)
	{
		warn "Warning: config file not defined";
		return undef;
	}
	elsif (not -e $config)
	{
		warn "Warning: config file $config does not exist";
		return undef;
	}
	else
	{
		my $yaml = YAML::Tiny->read($config) or warn "Could not read config file: ".YAML::Tiny->errstr;
		$self->_set_defaults($yaml->[0]) if (defined $yaml);
	}
}

sub _merge_properties
{
	my ($self, $prop_a, $prop_b) = @_;

	return undef if (not defined $prop_a and not defined $prop_b);
	return $prop_a if (not defined $prop_b);
	return $prop_b if (not defined $prop_a);

	return merge_hash_r($prop_a, $prop_b);
}

sub merge_hash_r
{
        my ($a, $b) = @_;

        my $new_hash = {};

        foreach my $key (keys %$a)
        {
                $new_hash->{$key} = $a->{$key};
        }

        foreach my $key (keys %$b)
        {
                my $value_b = $b->{$key};
                my $value_a = $new_hash->{$key};

                # if both defined, must merge
                if (defined $value_a and defined $value_b)
                {
                        # if the value is another hash, go through another level
                        if (defined $value_a and (ref $value_a eq 'HASH'))
                        {
                                $new_hash->{$key} = merge_hash_r($value_a,$value_b);
                        } # else if not another hash, overwrite a with b
                        else
                        {
                                $new_hash->{$key} = $value_b;
                        }
                } # if only b defined, copy over to a
                elsif (defined $value_b)
                {
                        $new_hash->{$key} = $value_b;
                }
                # else if only a defined, do nothing
        }

        return $new_hash;
}

sub _set_defaults
{
	my ($self, $defaults) = @_;

	warn "Defaults undefined" if (not defined $defaults);

	my $processors = $defaults->{'processors'};
	my $formatdb = $defaults->{'path'}->{'formatdb'};
	my $blastall = $defaults->{'path'}->{'blastall'};
	my $clustalw2 = $defaults->{'path'}->{'clustalw2'};
	my $figtree = $defaults->{'path'}->{'figtree'};
	my $phyml = $defaults->{'path'}->{'phyml'};

	$self->set_property('processors', $processors) if ((defined $processors) and ($processors =~ /^\d+$/));
	$self->set_file('formatdb', $formatdb) if ((defined $formatdb) and (-e $formatdb));
	$self->set_file('figtree', $figtree) if ((defined $figtree) and (-e $figtree));
	$self->set_file('phyml', $phyml) if ((defined $phyml) and (-e $phyml));
	$self->set_file('clustalw2', $clustalw2) if ((defined $clustalw2) and (-e $clustalw2));
	$self->set_file('blastall', $blastall) if ((defined $blastall) and (-e $blastall));
}

sub set_property
{
	my ($self, $key, $value) = @_;

	die "Undefined key" if (not defined $key);
	die "Undefined value" if (not defined $value);

	$self->{'_properties'}->{'properties'}->{$key} = $value;
}

sub get_property
{
	my ($self, $key) = @_;

	return $self->{'_properties'}->{'properties'}->{$key};
}

sub get_script_dir
{
	my ($self) = @_;

	return $self->{'_script_dir'};
}

sub set_job_dir
{
	my ($self, $job_dir) = @_;

	die "Undefined job_dir" if (not defined $job_dir);

	$self->{'_job_dir'} = $job_dir;
}

sub get_job_dir
{
	my ($self) = @_;

	return $self->{'_job_dir'};
}

sub set_dir
{
	my ($self, $key, $dir_value) = @_;

	die "Undefined key" if (not defined $key);
	die "Undefined value" if (not defined $dir_value);

	$self->{'_dirs'}->{$key} = $dir_value;	
}

sub set_abs_dir
{
	my ($self, $key, $dir_value) = @_;

	die "Undefined key" if (not defined $key);
	die "Undefined value" if (not defined $dir_value);

	$self->{'_properties'}->{'abs_dirs'}->{$key} = $dir_value;	
}

sub get_abs_dir
{
	my ($self, $dir_key) = @_;

	die "dir_key not defined" if (not defined $dir_key);

	return $self->{'_properties'}->{'abs_dirs'}->{$dir_key};
}

sub set_file
{
	my ($self, $key, $file_value) = @_;

	die "Undefined key" if (not defined $key);
	die "Undefined value" if (not defined $file_value);

	$self->{'_properties'}->{'files'}->{$key} = $file_value;	
}

sub get_dir
{
	my ($self,$dir_key) = @_;

	die "dir_key not defined" if (not defined $dir_key);

	my $job_dir = $self->{'_job_dir'};
	die "Undefined job_dir" if (not defined $job_dir);

	my $dir = $self->{'_dirs'}->{$dir_key};

	if (not defined $dir)
	{
		return undef;
	}
	else
	{
		return "$job_dir/$dir";
	}
}

sub get_file
{
	my ($self,$file_key) = @_;

	die "file_key not defined" if (not defined $file_key);

	my $job_dir = $self->{'_job_dir'};
	die "Undefined job_dir" if (not defined $job_dir);

	my $file = $self->{'_properties'}->{'files'}->{$file_key};

	if (not defined $file)
	{
		return undef;
	}
	else
	{
		return $file;
	}
}

sub get_file_dir
{
	my ($self, $dir_key, $file_key) = @_;

	die "file_key not defined" if (not defined $file_key);
	die "dir_key not defined" if (not defined $dir_key);

	my $job_dir = $self->{'_job_dir'};
	die "Undefined job_dir" if (not defined $job_dir);

	my $file = $self->{'_properties'}->{'files'}->{$file_key};
	my $dir = $self->{'_dirs'}->{$dir_key};

	if ((not defined $file) or (not defined $dir))
	{
		return undef;
	}
	else
	{
		return "$job_dir/$dir/$file";
	}
}

sub build_job_dirs
{
	my ($self) = @_;

	die "Job dir is not defined" if (not defined $self->{'_job_dir'});

	mkdir $self->{'_job_dir'} if (not -e $self->{'_job_dir'});

	for my $key (keys %{$self->{'_dirs'}})
	{
		my $dir = $self->get_dir($key);
		mkdir $dir if (defined $dir and not -e $dir);
	}
}

sub write_properties
{
	my ($self, $file) = @_;

	die "File is undefined" if (not defined $file);

	my $yaml_string = "# Properties for snp-phylogenomics job\n".
			"# Auto-generated on ".(localtime)."\n";

	open(my $out_fh, '>', $file) or die "Could not write to $file: $!";
	print $out_fh $yaml_string;
	print $out_fh $self->write_properties_string;
	close($out_fh);
}

sub write_properties_string
{
	my ($self) = @_;

	my $yaml_string;
	my $yaml = YAML::Tiny->new;
	$yaml->[0] = $self->{'_properties'};

	$yaml_string = $yaml->write_string;

	return $yaml_string;
}

sub read_properties
{
	my ($self,$file) = @_;

	die "File undefined" if (not defined $file);
	die "File $file does not exist" if (not -e $file);

	my $yaml = YAML::Tiny->read($file) or die "Could not read config file $file: ".YAML::Tiny->errstr;
	$self->{'_properties'} = $self->_merge_properties($self->{'_properties'}, $yaml->[0]);
}

1;
