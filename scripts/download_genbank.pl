#!/usr/bin/perl 
use strict;
use warnings;
use Bio::DB::GenBank;
use Bio::DB::Query::GenBank;
use File::Path;
use Getopt::Long;
use File::Spec;
use Text::CSV_XS qw(csv);

my $DEBUG = 0;
my $basedir = 'download';
my $force;
GetOptions(
    'v|d|debug'            => \$DEBUG,
    'f|force!'             => \$force,
    'b|basedir:s'          => \$basedir);

mkdir($basedir) unless -d $basedir;
my $ncbi_id_file = shift || 'lib/organisms.csv';
my $gb = Bio::DB::GenBank->new(-verbose => $DEBUG);

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
    my $query = Bio::DB::Query::GenBank->new(-db      => 'nucleotide',
                                             -verbose => $DEBUG,
                                             -query   => $qstring,
                                             );
    my $stream;
    eval { 
	$stream = $gb->get_Stream_by_query($query);
    };
    if( $@ ) {
	warn($qstring,"\n");
	warn($@);
	next;
    }

    while (my $seq = $stream->next_seq) {
        # do something with the sequence object
        my $acc = $seq->accession_number;
	my $targetfile = File::Spec->catfile($targetdir,"$acc.gbk.gz");
        warn("$targetfile\n") if $DEBUG;
	if( $force || ! -f $targetfile ) {
	    Bio::SeqIO->new(-format => 'genbank',
			    -file   => "|gzip -c > $targetfile")->write_seq($seq);	
	} else {
	    warn("$targetfile already present... skipping\n");
	}
    }
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

