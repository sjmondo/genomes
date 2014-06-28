    #!/usr/bin/perl 
use strict;
use warnings;
use Bio::DB::GenBank;
use Bio::DB::Query::GenBank;
use File::Path;
use Getopt::Long;
use File::Spec;
my $DEBUG = 0;
my $basedir = 'download';
my $force;
GetOptions(
    'v|d|debug'            => \$DEBUG,
    'f|force!'             => \$force,
    'b|basedir:s'          => \$basedir);

mkdir($basedir) unless -d $basedir;
my $ncbi_id_file = shift || 'lib/accessions.csv';
my $gb = Bio::DB::GenBank->new(-verbose => $DEBUG);
open(QUERY, $ncbi_id_file) || die $!;


while(<QUERY>) {
    next if /^\#/ || /^\s+$/ || /^Species/;
    chomp;
    my ($species,$strain,$family,$source,$accessions,$pmid) = split(/,/,$_);
    next if ! $accessions;
    my $speciesnospaces = $species;
    $speciesnospaces =~ s/[\s\/#]/_/g;

    my $targetdir = File::Spec->catfile($basedir,$family,$speciesnospaces);
    mkpath($targetdir);
    opendir(DIR => $targetdir) || die "Cannot open $targetdir";
    my @not;
    
    for my $p ( readdir(DIR) ) {
	if( $p =~ /(\S+)\.gbk\.gz/ ) {
	    push @not, sprintf("NOT %s[ACCN]",$1);
	}
    }
    my @qstring;
    my $keep;
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
            push @qstring, sprintf("%s:%s[ACCN]",$start,$finish);
            for(my $i = $s_number; $i <= $f_number; $i++) {
                my $acc = sprintf("%s%0".$nl."d",$s_letter,$i);
                if( -f File::Spec->catfile($basedir,$species,"$acc.gbk.gz")) {
                    push @not, sprintf("NOT %s[ACCN]",$acc);
                } else {
                    $keep++;
                }
            }

        } else {
            next if -f File::Spec->catfile($basedir,$species,"$start.gbk.gz");
            push @qstring, sprintf("%s[ACCN]",$start);
            $keep++;
        }
    }
    next unless (@qstring && $keep);
    my $qstring = join(" OR ", @qstring) . " " . join(" ",@not);
    warn("qstring is $qstring\n") if $DEBUG;
    my $query = Bio::DB::Query::GenBank->new(-db=>'nucleotide',
                                             -verbose => $DEBUG,
                                             -query=>$qstring,
                                             );
    my $stream = $gb->get_Stream_by_query($query);

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
