#!env perl
use strict;
use warnings;
use Bio::SeqIO;
use Bio::Seq;

my $dir = shift || 'final_combine/GFF';
my $odir = shift || 'final_combine/pep';
opendir(DIR,$dir) || die $!;
my $abbrev_table = "prefix_lookup.tab";
open( my $ofh => ">$abbrev_table") || die "$abbrev_table: $!";
for my $file ( sort readdir(DIR) ) {
    next unless $file =~ /(\S+)\.gff3/;
    my $stem = $1;
    my ($genus,$species,@rest) = split(/_/,$stem);
    my $prefix = substr($genus,0,1).substr($species,0,3);
    print $ofh join("\t", $prefix,join(" ",$genus,$species,@rest)),"\n";
    open(my $fh => "$dir/$file" ) || die $!;
    my $outpep = Bio::SeqIO->new(-format => 'fasta',
				 -file   => ">$odir/$stem.aa.fasta");
    while(<$fh>) {
	next if /^\#/;
	chomp;
	my @row = split(/\t/,$_);
	next unless $row[2] eq 'mRNA';
	my %lastcol = map { my $n = $_;
			    my @r = ( $n =~ /(\S+)=(\S+)/ ) ? split(/=/,$n) : ();			    
	} split(/;/,$row[-1]);
	my $name = $lastcol{'Name'};
	if( ! defined $name ) {
	    warn("cannot find name for @row \n");
	} else {
	    $name =~ s/\.tr$//;
	}
	if( exists $lastcol{Note} && 
	    $lastcol{Note} =~ /tRNA/ ) {
	    next;
	} elsif( ! defined $lastcol{translation} ) {
	    warn("no translation for $name\n");
	    next;
	}
	my $pseq = Bio::Seq->new(-seq => $lastcol{translation},
				 -id  => "$prefix|$name");
	
	$outpep->write_seq($pseq);
    }
}
