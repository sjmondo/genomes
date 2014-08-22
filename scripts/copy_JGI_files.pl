#!/usr/bin/perl
use strict;
use warnings;
my $debug =0;
my $debug_one = 1;
my $force = 0;
my $dir = shift || "download";
my $p_odir = shift || 'final_combine/pep';
my $g_odir = shift || 'final_combine/GFF';
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
	    if( $file =~ /(\S+\.aa\.fasta).gz$/) {
		my $stem = $1;
		next if -f "$p_odir/$stem";
		print("zcat $dir/$f/$sp/$file | ",
		      'perl -p -e \'s/^>(\w+)\|(\S+)\|(\d+)\|(\S+)/>$2|$2_$3 $4/\' > ',"$p_odir/$stem\n");
	    } elsif ( $file =~ /(\S+\.gff3).gz$/) {
		my $stem = $1;
		next if !$force && -f "$g_odir/$stem";
		open(my $in => "zcat $dir/$f/$sp/$file |") || die $!;
		open(my $out => ">$g_odir/$stem")|| die $!;
		while(<$in>) {
		    if( ! /^\#/ ) {
			chomp;
			my @row = split(/\t/,$_);
			my $last = pop @row;
			my (@order,%ninth);
			for my $ent ( split(/;/,$last) ) {
			    my ($id,$val) = split(/=/,$ent);
			    $ninth{$id} = $val;
			    push @order, $id;
			}
			if( exists $ninth{'Name'} ) {
			    my $val = $ninth{'Name'};
			    if( $val =~ /jgi\.p\|(\S+)\|(\d+)\|?$/ ) {
				$val = "$1|$1\_$2";
			    }
			    $ninth{'Name'} = $val;
			}
			push @row, join(";", map { sprintf("%s=%s", $_,
							   $ninth{$_}) }
					@order);
						       
			$_= join("\t",@row)."\n";
		    } 
		    print $out $_;
		}
		close($in);
		close($out);
	    }
	}
#	last if $debug_one;
    }
}
