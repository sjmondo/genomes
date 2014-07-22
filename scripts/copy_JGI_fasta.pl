#!/usr/bin/perl
use strict;
use warnings;
my $debug =0;
my $dir = shift || "download";
my $odir = shift || 'final_combine/pep';
opendir(DIR, $dir) || die $!;
for my $f ( readdir(DIR) ) {
    next if $f =~ /^\./;
    opendir(FAM,"$dir/$f") || die $!;
    for my $sp ( readdir(FAM) ) {
	next if $sp =~ /^\./;
	next if ( ! -d "$dir/$f/$sp");
	warn("sp is $dir/$f/$sp\n") if $debug;
	opendir(SP,"$dir/$f/$sp") || die "$dir/$f/$sp $!";
	for my $file ( readdir(SP) ) {
	    next unless $file =~ /(\S+\.aa\.fasta).gz$/;
	    my $stem = $1;
	    next if -f "$odir/$stem";
	    print("zcat $dir/$f/$sp/$file | ",
		  'perl -p -e \'s/^>(\w+)\|(\S+)\|(\d+)\|(\S+)/>$2|$2_$3 $4/\' > ',"$odir/$stem\n");
	}
    }
}
