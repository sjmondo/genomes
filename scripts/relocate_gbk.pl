#!/usr/bin/perl
use strict;
use warnings;
my $dir = shift || "download";
opendir(DIR, $dir) || die $!;
for my $f ( readdir(DIR) ) {
    next if $f =~ /^\./;
    opendir(FAM,"$dir/$f") || die $!;
    for my $sp ( readdir(FAM) ) {
	next if $sp =~ /^\./;
	warn("sp is $dir/$f/$sp\n");
	if( -d "$dir/$f/$sp/gbk" ) {
#	    warn("already exists $dir/$f/$sp/gbk\n");
	} else {
	    warn("$dir/$f/$sp/gbk \n");
	    mkdir("$dir/$f/$sp/gbk");
	}
	opendir(SP,"$dir/$f/$sp") || die "$dir/$f/$sp $!";
	for my $file ( readdir(SP) ) {
	    next unless $file =~ /\.gbk\.gz$/;
	    print("mv $dir/$f/$sp/$file $dir/$f/$sp/gbk/$file\n");
	}
    }
}
