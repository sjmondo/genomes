#!env perl
use strict;
use warnings;
use Text::CSV_XS qw(csv);
use XML::Simple;
use Data::Dumper;
use Getopt::Long;
use File::Spec;


my $url_base = 'http://genome.jgi.doe.gov';
my $outdir = 'downloads';

my $genome_file = 'lib/organisms.csv';
# data fields
my @data_fields = qw(label filename md5 timestamp); # removed 'url' as it was redundant here
my $download_cmds = "jgi_download_curl.sh";
my $cookie_file = '.JGI_cookie';
my $debug = 0;
my $infile;  # input file with XML
GetOptions(
    'v|debug|verbose!' => \$debug,
    'i|input:s'        => \$infile,
    'cookie:s'         => \$cookie_file,
    'g|genomes:s'      => \$genome_file,
    'o|dir|outdir:s'   => \$outdir,
    'download|script:s' => \$download_cmds,
    );

$infile = shift @ARGV unless defined $infile;

die "must provide an input file via -i or single argument" 
    if ! defined $infile;

#init the XML parser
my $xs = XML::Simple->new;

print join("\t", qw(Type Prefix LocalFile), @data_fields),"\n";
# Read whole file in memory as hash of hashes
my $csv = Text::CSV_XS->new ({ binary => 1, auto_diag => 1 });
open my $fh, "<:encoding(utf8)", $genome_file or die "$genome_file: $!";

my $parsed = $xs->XMLin($infile);
my $folder = $parsed->{folder}->{folder};

my %orgs;
my %jgi_targets;
while (my $row = $csv->getline ($fh)) {
    next if( $row->[0] =~ /^\#/);
    $orgs{$row->[0]} = { 'strain' => $row->[1],
			 'family' => $row->[2],
			 'source' => $row->[3] };
    if( $row->[3] eq 'JGI' ) {
	# keep track of the species which we would like to get from JGI 
	$jgi_targets{$row->[0]} = 1;
    }
}

open(my $curl_cmds => ">$download_cmds") || die $!;

#warn(Dumper($fungi));
warn("types are: ", join(",", keys %$folder),"\n") if $debug;
my %data;
my $first = 1;
while( my ($type,$d) = each %$folder ) {
    if( $type eq 'Assembly' ) {
	my $asm = $d->{folder};
	while( my ($k,$n) = each %$asm ) {
	    if( $k eq 'Assembled scaffolds (unmasked)') {
		# sorting here on the prefix by extracting the prefix from 
		# $file->{url} which has '/' separating the path
		# so (split(/\//,$_->{url}))[1] gets the 2nd entry which 
		# is the prefix
		# this creates a new data structure
		# [ prefix, filehash (from the XML)]
		# now we can sort by the prefix -> hence the sort
		for my $file_obj ( 
		    sort { $a->[0] cmp $b->[0] }
		    map {[(split(/\//,$_->{url}))[1],$_]  } 
			       @{$n->{file}} ) {
		    my ($prefix,$file) = @$file_obj;
		    my $fullurl = sprintf("%s%s",$url_base,
					   $file->{url});
		    $file->{label} =~ s/(\s+var)(\s+)/$1.$2/;
		    my @label_spl = split(/\s+/,$file->{label});

		    my $name;
		    if( $file->{label} =~ /\s+var(\.)?\s+/ ) {
			$name = join(" ", $label_spl[0],$label_spl[1],
				     $label_spl[2],$label_spl[3]);
		    } elsif ($file->{label} =~ /\s+f\.\s+sp\.\s+/ ) {
			$name = join(" ", $label_spl[0],$label_spl[1],
				     $label_spl[2],$label_spl[3],
				     $label_spl[4]);
		    } else {
			$name = join(" ", $label_spl[0],$label_spl[1]);
		    }
		    if( ! exists $orgs{$name} ) {
			#warn("cannot find '$name' in the query file\n");
			next;
		    }
		    
		    if( $jgi_targets{$name} ) {
			my $family = $orgs{$name}->{family};
			my $oname = $name;
			$oname =~ s/\s+/_/g;
			$oname =~ s/\.$//g; # remove trailing periods for things that are like XX sp. 	
			my $outfile = File::Spec->catfile($outdir,$family,$oname,"$oname.assembly.fasta.gz");

			print join("\t", "Genome",$prefix,
				   $outfile,
				   map { $file->{$_} || ''} @data_fields),"\n";


			if( ! -f $outfile ) {
			    print $curl_cmds "curl $fullurl -b $cookie_file -o $outfile --create-dirs\n";
			}
			$jgi_targets{$name} = 2;
		    }
		}
	    } 
	}
    } elsif( $type eq 'Annotation' ) {
	my $asm = $d->{folder};
	while( my ($k,$n) = each %$asm ) {
	    if( $k eq 'Filtered Models ("best")' ) {
		for my $ftype ( qw(Proteins CDS) ) {
		    my $f = $n->{'folder'}->{$ftype};
		    for my $file_obj ( 
			sort { $a->[0] cmp $b->[0] }
			map {[(split(/\//,$_->{url}))[1],$_]  } 
			@{$f->{file}} ) {
			my ($prefix,$file) = @$file_obj;			
			my $fullurl = sprintf("%s%s",$url_base,
					      $file->{url});
			$file->{label} =~ s/(\s+var)(\s+)/$1.$2/;
			my @label_spl = split(/\s+/,$file->{label});
			
			my $name;
			if( $file->{label} =~ /\s+var(\.)?\s+/ ) {
			    $name = join(" ", $label_spl[0],$label_spl[1],
					 $label_spl[2],$label_spl[3]);
			} elsif ($file->{label} =~ /\s+f\.\s+sp\.\s+/ ) {
			    $name = join(" ", $label_spl[0],$label_spl[1],
					 $label_spl[2],$label_spl[3],
					 $label_spl[4]);
			} else {
			    $name = join(" ", $label_spl[0],$label_spl[1]);
			}
			warn("name is $name ftype is $ftype url is $fullurl\n") if $debug;
			if( ! exists $orgs{$name} ) {
			    #warn("cannot find '$name' in the query file\n");
			    next;
			}
			
			if( $jgi_targets{$name} ) {
			    my $family = $orgs{$name}->{family};
			    my $oname = $name;
			    $oname =~ s/\s+/_/g;
			    $oname =~ s/\.$//; # remove trailing periods for things that are like XX sp. 
			    my $outfile = File::Spec->catdir($outdir,$family,$oname);
			    next if $fullurl =~ /\.tar.gz$/ || $fullurl =~ /ESTs/; # skip the compiled set of all gene modules (tar.gz) or the EST fastas
			    if( $fullurl =~ /\.gff/ ) {
				$outfile = File::Spec->catfile($outfile,"$oname.gff3.gz");
			    } elsif( $fullurl =~ /\.aa\./) {
				$outfile = File::Spec->catfile($outfile,"$oname.aa.fasta.gz");
			    } elsif( $fullurl =~ /CDS/ ) {
				$outfile = File::Spec->catfile($outfile,"$oname.CDS.fasta.gz");
			    }
			    print join("\t",  $ftype,$prefix,$outfile,
				       map { $file->{$_} || ''} 
				       @data_fields),"\n";
			
			    if( ! -f $outfile ) {
				print $curl_cmds "curl $fullurl -b $cookie_file -o $outfile --create-dirs\n";
			    }
			    $jgi_targets{$name} = 2;
			}	
		    }		    
		}
	    }
	}
    }
}

my @missing;
for my $name ( sort keys %jgi_targets ) {
    if( $jgi_targets{$name} == 1 ) {
	push @missing, $name;
    }
}
if( @missing ) {
    warn("Missing the following JGI targets: \n", join("\n", @missing),"\n");
}
