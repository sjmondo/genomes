#!env perl
use strict;
use warnings;

use LWP::Simple;
use Encode;
use Cache::File;
use Bio::SeqIO;
use IO::String;
#use Bio::DB::GenBank;
#use Bio::DB::FileCache;
use XML::Simple;
use Text::CSV_XS qw(csv);
use File::Spec;
use Getopt::Long;
use Data::Dumper;
use Env qw(USER);

my $out = Bio::SeqIO->new(-format => 'genbank');

my $SLEEP_TIME = 2;
my $cache_dir = "eutils_".$ENV{USER}.".cache";
my $cache_filehandle;
my $cache_keep_time = '1 day';

my $base = 'http://eutils.ncbi.nlm.nih.gov/entrez/eutils/';

my $force = 0;
my $debug = 0;
my $retmax = 1000;
my $runonce = 0;
my $use_cache = 1;
my $dbfile = 'lib/accessions.csv';
GetOptions(
    'debug|v!'  => \$debug,
    'runonce!'  => \$runonce,
    'retmax:i'  => \$retmax,
    'i|db:s'    => \$dbfile,
    'f|force!'  => \$force, # force downloads even if file exists
    'cache!'    => \$use_cache,
    );

$SLEEP_TIME = 0 if $debug; # let's not wait when we are debugging

if( $use_cache ) {
    &init_cache();
}

# Read whole file in memory as array of arrays
my $csv = Text::CSV_XS->new ({ binary => 1, auto_diag => 1 });
open my $fh, "<:encoding(utf8)", $dbfile or die "$dbfile: $!";
my $xs = XML::Simple->new;
while (my $row = $csv->getline ($fh)) {    

    if( $row->[0] =~ /^\#/ || ( $row->[4] && ! $force) ) {
	$csv->print(\*STDOUT, $row);
	print "\n";
	next;
    }
    $row->[4] = '' if $force;

    my $query = $row->[0];
    if ( $row->[1] ) {
	$query .= " ".$row->[1];
    }
    my %notes;
    if( $row->[6] ) {
	%notes = map { $_ => 1 } split(/;/,$row->[6]);
    }
    my $db = 'genome';
    my $url = sprintf("esearch.fcgi?db=%s&term=%s&rettype=acc&retmax=%d&usehistory=y",
		      $db,$query,$retmax);

    warn "url is $url\n" if $debug;
    my $output = get_web_cached($base,$url);
#    my ($web,$key,$count);   
#    if( $output =~ /<WebEnv>(\S+)<\/WebEnv>/) {
#	$web = $1;
#    }
#    if ($output =~ /<QueryKey>(\d+)<\/QueryKey>/) {
#	$key = $1;
#    }
#    if( $output =~ /<Count>(\d+)<\/Count>/) {
#	$count = $1;
#    }
    
    my @ids;
    while ($output =~ /<Id>(\d+?)<\/Id>/sg) {
	push(@ids, $1);
    }

    if( ! @ids ) {
	$query = $row->[0];
	$url = sprintf("esearch.fcgi?db=%s&term=%s&rettype=acc&retmax=%d&usehistory=y",
		       $db,$query,$retmax);

	warn "url is $url\n" if $debug;
	$output = get_web_cached($base,$url);
	while ($output =~ /<Id>(\d+?)<\/Id>/sg) {
	    push(@ids, $1);
	}
    }
    warn "processing ", scalar @ids," project IDs for $query\n";
    
    for my $id ( @ids ) {    
	warn( "id is $id\n") if $debug;
	$url = sprintf('elink.fcgi?dbfrom=genome&db=nuccore&id=%d&term=srcdb+refseq[prop]',$id);    
	# post the elink URL
	$output = get_web_cached($base,$url);    
	warn($output) if $debug;
	my $simplesum;
	eval {
	    $simplesum = $xs->XMLin($output);
	};
	if( $@ ) {
	    delete_cache($base,$url);
	    next;
		}
	my $doc = $simplesum->{LinkSet};
	my $ls = $doc->{LinkSetDb}->{Link};
	my @nucl_ids;
	if( ref($ls) =~ /HASH/ ) {
	    $ls = [$ls];
	}
	for my $link ( @$ls ) {
	    my $id = $link->{Id};
	    push @nucl_ids, $id;
	}

	if( @nucl_ids ) {
	    $notes{RefSeq}++;
	} else {
	    $url = sprintf('elink.fcgi?dbfrom=genome&db=nuccore&id=%d&term=wgs[prop]',$id);    
	    # post the elink URL
	    $output = get_web_cached($base,$url);    
	    warn($output) if $debug;
	    my $simplesum;
	    eval {
		$simplesum = $xs->XMLin($output);
	    };
	    if( $@ ) {
		delete_cache($base,$url);
		next;
	    }
	    my $doc = $simplesum->{LinkSet};
	    my $ls = $doc->{LinkSetDb}->{Link};
	    if( ref($ls) =~ /HASH/ ) {
		$ls = [$ls];
	    }
	    for my $link ( @$ls ) {
		my $id = $link->{Id};
		push @nucl_ids, $id;
	    }
	    if( @nucl_ids ) {
		$notes{WGS}++;
	    }
	    warn("nucl_ids are @nucl_ids\n") if $debug;
	}

	unless( @nucl_ids ) {
	    warn("no IDs for GenomeProject $id\n");
	}
	for my $gi ( @nucl_ids ) {
	    $url = sprintf('efetch.fcgi?retmode=text&rettype=gb&db=nuccore&tool=bioperl&id=%s',$gi);       
	    $output = get_web_cached($base,$url);
	    warn($output) if $debug;
	    my $ios = IO::String->new($output);
	    my (@acc,@seqacc,$src);
	    my $i = 0;
	    my $skip = 0;
	    while(<$ios>) {
		if( /ORGANISM\s+(.+)/ ) {
		    $src = $1;
		} elsif(/WGS_SCAFLD\s+(\S+)/ ) {
		    push @acc, $1;
		} elsif(/^ACCESSION\s+(\S+)/) {
		    push @seqacc, $1;
		} elsif( /^DEFINITION|SOURCE/ && /mitochondrion/ ) {
		    $skip =1;
		}
		last if $i++ > 10000;
	    }
	    next if $skip;
	    if( $src ne $query && $row->[1] ) {
		warn("$src not $query\n");
	    } else {
		if( ! @acc ) { 
		    @acc = @seqacc;
		}
		if( $row->[4] ) { 
		    $row->[4] = join(";",$row->[4],@acc);
		} else {
		    $row->[4] = join(";",@acc);
		}
	    }
	}
    }
    $row->[6] = join(";",sort keys %notes);
    $csv->print(\*STDOUT,$row);
    print "\n";
    last if $runonce;
}

sub init_cache {
    if( ! $cache_filehandle ) {
	mkdir($cache_dir) unless -d $cache_dir;	
	$cache_filehandle = Cache::File->new( cache_root => $cache_dir);
    }
}

sub get_web_cached {
    my ($base,$url) = @_;
    if( ! defined $base || ! defined $url ) {
	die("need both the URL base and the URL stem to proceed\n");
    }
    unless( $use_cache ) {
	sleep $SLEEP_TIME;
	return get($base.$url);
    }
    my $val = $cache_filehandle->get($url);
    unless( $val ) {
	warn("not in cache\n") if $debug;
	$val = encode("utf8",get($base.$url));
	sleep $SLEEP_TIME;
	$cache_filehandle->set($url,$val,$cache_keep_time);
    } 
    return decode("utf8",$val);    
}

sub delete_cache {
    my ($base,$url) = @_;
    return unless $use_cache;

    if( ! defined $base || ! defined $url ) {
	die("need both the URL base and the URL stem to proceed\n");
    }

    $cache_filehandle->remove($base.$url);
}
