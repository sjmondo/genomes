#!env perl
use strict;
my $dir= shift || "final_combine/pep";
opendir(DIR, $dir) || die "dir is $dir: $!";
for my $file ( sort readdir(DIR) ) {
    next unless $file =~ /(\S+)\.aa\.fasta/;
    my $stem = $1;
    $stem =~ s/\.([_.])/$1/g;
    my @parts = split(/\./,$stem);
    my ($genus,$species) = split(/_/,$parts[0]);
    my $pref;
    if( @parts > 1 ) {
	$pref = $parts[1];
    } else {
	$pref = substr($genus,0,1).substr($species,0,3);
    }
    print join("\t",$pref,$parts[0]), "\n";
}
