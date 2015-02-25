#!/usr/bin/env perl

package JobProperties;

use YAML::Tiny;

use strict;
use warnings;

use File::Path;

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
	$self->{'_properties'}->{'abs_files'} = {};

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
	my $drmaa_params = $defaults->{'drmaa_params'};
	my $min_coverage = $defaults->{'min_coverage'};
	my $max_coverage = $defaults->{'max_coverage'};
	my $freebayes_params = $defaults->{'freebayes_params'};
	my $trim_clean_params = $defaults->{'trim_clean_params'};
	my $smalt_map_params = $defaults->{'smalt_map'};
	my $smalt_index_params = $defaults->{'smalt_index'};
	my $formatdb = $defaults->{'path'}->{'formatdb'};
	my $blastall = $defaults->{'path'}->{'blastall'};
	my $clustalw2 = $defaults->{'path'}->{'clustalw2'};
	my $figtree = $defaults->{'path'}->{'figtree'};
	my $phyml = $defaults->{'path'}->{'phyml'};
	my $smalt = $defaults->{'path'}->{'smalt'};
	my $samtools = $defaults->{'path'}->{'samtools'};
	my $bcftools = $defaults->{'path'}->{'bcftools'};
	my $bgzip = $defaults->{'path'}->{'bgzip'};
	my $tabix = $defaults->{'path'}->{'tabix'};
	my $freebayes = $defaults->{'path'}->{'freebayes'};
	my $vcftools = $defaults->{'path'}->{'vcftools-lib'};
	my $fastqc = $defaults->{'path'}->{'fastqc'};
	my $java = $defaults->{'path'}->{'java'};
	my $shuf = $defaults->{'path'}->{'shuf'};
	
        my $vcf2pseudo_numcpus = $defaults->{'vcf2pseudo_numcpus'};
        my $vcf2core_numcpus = $defaults->{'vcf2core_numcpus'};
	

	$self->set_property('smalt_index', $smalt_index_params) if (defined $smalt_index_params);
	$self->set_property('smalt_map', $smalt_map_params) if (defined $smalt_map_params);
	$self->set_property('processors', $processors) if ((defined $processors) and ($processors =~ /^\d+$/));
	$self->set_property('drmaa_params',$drmaa_params) if (defined $drmaa_params);
        $self->set_property('vcf2pseudo_numcpus',$vcf2pseudo_numcpus) if (defined $vcf2pseudo_numcpus);
        $self->set_property('vcf2core_numcpus',$vcf2core_numcpus) if (defined $vcf2core_numcpus);
        

	if (defined $freebayes_params)
	{
		if ($freebayes_params =~ /--min-coverage/ or $freebayes_params =~ /-!/)
		{
			die "do not set --min-coverage in config file for freebayes_params='$freebayes_params'";
		}
		else
		{
			$self->set_property('freebayes_params', $freebayes_params);
		}
	}

	if (defined $trim_clean_params)
	{
		if ($trim_clean_params =~ /-i\s/ or $trim_clean_params =~ /-o\s/)
		{
			die "do not set -i or -o in config file for trim_clean_params='$trim_clean_params'";
		}
		else
		{
			$self->set_property('trim_clean_params', $trim_clean_params);
		}
	}
	$self->set_property('min_coverage', $min_coverage) if ((defined $min_coverage) and ($min_coverage =~ /^\d+$/));
	$self->set_property('max_coverage', $max_coverage) if ((defined $max_coverage) and ($max_coverage =~ /^\d+$/));

	$self->set_file('formatdb', $formatdb) if ((defined $formatdb) and (-e $formatdb));
	$self->set_file('figtree', $figtree) if ((defined $figtree) and (-e $figtree));
	$self->set_file('phyml', $phyml) if ((defined $phyml) and (-e $phyml));
	$self->set_file('clustalw2', $clustalw2) if ((defined $clustalw2) and (-e $clustalw2));
	$self->set_file('blastall', $blastall) if ((defined $blastall) and (-e $blastall));
	$self->set_file('smalt', $smalt) if ((defined $smalt) and (-e $smalt));
	$self->set_file('samtools', $samtools) if ((defined $samtools) and (-e $samtools));
	$self->set_file('bcftools', $bcftools) if ((defined $bcftools) and (-e $bcftools));
	$self->set_file('bgzip', $bgzip) if ((defined $bgzip) and (-e $bgzip));
	$self->set_file('tabix', $tabix) if ((defined $tabix) and (-e $tabix));
	$self->set_file('freebayes', $freebayes) if ((defined $freebayes) and (-e $freebayes));
	$self->set_file('vcftools-lib', $vcftools) if ((defined $vcftools) and (-e $vcftools));
	$self->set_file('fastqc', $fastqc) if ((defined $fastqc) and (-e $fastqc));
	$self->set_file('java', $java) if ((defined $java) and (-e $java));
	$self->set_file('shuf', $shuf) if ((defined $shuf) and (-e $shuf));
	
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

sub set_abs_file
{
	my ($self, $key, $dir_value) = @_;

	die "Undefined key" if (not defined $key);
	die "Undefined value" if (not defined $dir_value);

	$self->{'_properties'}->{'abs_files'}->{$key} = $dir_value;	
}

sub get_abs_file
{
	my ($self, $dir_key) = @_;

	die "dir_key not defined" if (not defined $dir_key);

	return $self->{'_properties'}->{'abs_files'}->{$dir_key};
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
		mkpath $dir if (defined $dir and not -e $dir);
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
