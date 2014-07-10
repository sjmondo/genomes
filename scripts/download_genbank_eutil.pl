#!/usr/bin/perl 
use strict;
use warnings;
use Data::Dumper;
use File::Path;
use Getopt::Long;
use File::Spec;
use Text::CSV_XS qw(csv);
use LWP::Simple;
use XML::Simple;
use Encode;
use Cache::File;
use Bio::SeqIO;
use IO::String;

my $base = 'http://eutils.ncbi.nlm.nih.gov/entrez/eutils/';
my $SLEEP_TIME = 2;
my $cache_dir = "eutils_".$ENV{USER}.".cache";
my $cache_filehandle;
my $cache_keep_time = '1 day';

my $force = 0;
my $debug = 0;
my $retmax = 1000;
my $runonce = 0;
my $use_cache = 1;

my $DEBUG = 0;
my $basedir = 'download';
GetOptions(
    'runonce!'  => \$runonce,
    'retmax:i'  => \$retmax,
    'f|force!'  => \$force, # force downloads even if file exists
    'cache!'    => \$use_cache,
    'v|d|debug'            => \$DEBUG,
    'f|force!'             => \$force,
    'b|basedir:s'          => \$basedir);

mkdir($basedir) unless -d $basedir;
my $ncbi_id_file = shift || 'lib/accessions.csv';

my $db = 'nuccore';
$SLEEP_TIME = 0 if $debug; # let's not wait when we are debugging
if( $use_cache ) {
    &init_cache();
}
my $xs = XML::Simple->new;
my $csv = Text::CSV_XS->new ({ binary => 1, auto_diag => 1 });
open my $fh, "<:encoding(utf8)", $ncbi_id_file or die "$ncbi_id_file: $!";
while (my $row = $csv->getline ($fh)) {    
    next if $row->[0] =~ /^(\#|\s+|Species)/;
    my ($species,$strain,$family,$source,$accessions,$pmid) = @$row;
    next if ! $accessions;
    my $speciesnospaces = $species;
    $speciesnospaces =~ s/[\s\/#]/_/g;

    my $targetdir = File::Spec->catfile($basedir,$family,$speciesnospaces);
    mkpath($targetdir);
#    opendir(DIR => $targetdir) || die "Cannot open $targetdir";
#    my @not;
#    my %seen;    
#    for my $p ( readdir(DIR) ) {
#	if( $p =~ /(\S+)\.gbk\.gz/ ) {
#	    push @not, sprintf("NOT %s[ACCN]",$1);
#	}
#    }
    my %acc_query;
    for my $pair ( split(/;/,$accessions) ) {
        my ($start,$finish) = split(/-/,$pair);
        my ($s_letter,$s_number, $f_letter,$f_number);
        my $nl;
        if( $start =~ /^([A-Za-z_]+)(\d+)/ ) {
            $nl = length($2);
            ($s_letter,$s_number) = ($1,$2);
        } else {
            warn("Cannot process accession pair $pair\n");
            next;
        }
	$acc_query{$s_letter}->{nl} = $nl;
        if( $finish ) {
            if( $finish =~ /^([A-Za-z_]+)(\d+)/ ) {
                ($f_letter,$f_number) = ($1,$2);
            }  else {
                warn("Cannot process accession pair $pair\n");
                next;
            }
            if( $f_letter ne $s_letter ) {
                warn("Accession set does not match in $pair ($f_letter, $s_letter)\n");
                next;
            }
            for(my $i = $s_number; $i <= $f_number; $i++) {
		my $acc = sprintf("%s%0".$nl."d",$s_letter,$i);
                if( ! -f File::Spec->catfile($targetdir,"$acc.gbk.gz")) {
		    $acc_query{$s_letter}->{n}->{$i}++;
                }
            }
        } else {
            next if -f File::Spec->catfile($targetdir,"$start.gbk.gz");
	    $acc_query{$s_letter}->{n}->{$s_number}++;
        }
    }
    next unless keys %acc_query;
    my @qstring;
    for my $l ( keys %acc_query ) {
	my @nums = sort { $a <=> $b } map { int($_) } keys %{$acc_query{$l}->{n}};
	my @collapsed = collapse_nums(@nums);
	my $nl = $acc_query{$l}->{nl};
	for my $nm ( @collapsed ) {
	    if( $nm =~ /[-]/ ) {		
		my ($from,$to) = split('-',$nm);
		$from = sprintf("%s%0".$nl."d",$l,$from);
		$to = sprintf("%s%0".$nl."d",$l,$to);
		push @qstring,sprintf("%s:%s[ACCN]",$from,$to)
	    } else {
		my $nm2 = sprintf("%s%0".$nl."d",$l,$nm);
		push @qstring,sprintf("%s[ACCN]",$nm2);
	    }
	}
    }
    next unless (@qstring);
    my $qstring = join(" OR ", @qstring); #  . " " . join(" ",@not);
    warn("query for $species\n") if $DEBUG;
    warn("qstring is $qstring\n") if $DEBUG;

    my $url = sprintf('esearch.fcgi?db=nuccore&tool=bioperl&term=%s',$qstring);
    #delete_cache($base,$url);
    my $output = get_web_cached($base,$url);
    my $simplesum;
    eval {
	$simplesum = $xs->XMLin($output);
    };
    if( $@ ) {
	    delete_cache($base,$url);
	    next;
    }
    my $ids = $simplesum->{IdList}->{Id};
    if( ref($ids) !~ /ARRAY/ ) {
	$ids = [$ids];
    }
    for my $id ( @$ids ) {
	$url = sprintf('efetch.fcgi?retmode=text&rettype=gbwithparts&db=nuccore&tool=bioperl&id=%s',$id);
	#delete_cache($base,$url);
	$output = get_web_cached($base,$url);
	my $acc;
	my $io = IO::String->new($output);
	while(<$io>) {
	    if( /^ACCESSION\s+(\S+)/ ) {
		$acc = $1;
		last;
	    } elsif(/^FEATURES/) {
		last;
	    }	    
	}
#	if( $output =~ /ACCESSION\s+(\S+)/ ) {
#	    $acc = $1;
#	} 
	unless( $acc ) {
	    warn("no Accession for $id\n");
	    $acc = $id;
	}
	my $targetfile = File::Spec->catfile($targetdir,"$acc.gbk.gz");
	open(my $ofh => "| gzip -c > $targetfile") || die $!;
	print $ofh $output;
	last if $runonce;
    }
    last if $runonce;
}

sub collapse_nums {
#------------------
# This is probably not the slickest connectivity algorithm, but will do for now.
    my @a = @_;
    my ($from, $to, $i, @ca, $consec);

    $consec = 0;
    for($i=0; $i < @a; $i++) {
	not $from and do{ $from = $a[$i]; next; };
	if($a[$i] == $a[$i-1]+1) {
	    $to = $a[$i];
	    $consec++;
	} else {
	    if($consec == 1) { $from .= ",$to"; }
	    else { $from .= $consec>1 ? "\-$to" : ""; }
	    push @ca, split(',', $from);
	    $from =  $a[$i];
	    $consec = 0;
	    $to = undef;
	}
    }
    if(defined $to) {
	if($consec == 1) { $from .= ",$to"; }
	else { $from .= $consec>1 ? "\-$to" : ""; }
    }
    push @ca, split(',', $from) if $from;
    @ca;
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
	warn("$base$url not in cache\n") if $debug;
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
