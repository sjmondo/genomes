#!env perl
use strict;
use Getopt::Long;
use Text::CSV_XS qw(csv);
my $genome_file = 'lib/organisms.csv';
# data fields
my $debug = 0;
my $outdir = 'final_combine';
my @target_dirs = qw(pep CDS DNA GFF);
GetOptions(
    'v|debug|verbose!' => \$debug,
    'g|genomes:s'      => \$genome_file,
    'o|dir|outdir:s'   => \$outdir,
    );

my %orgs;
my %jgi_targets;
my $csv = Text::CSV_XS->new ({ binary => 1, auto_diag => 1 });
open my $fh, "<:encoding(utf8)", $genome_file or die "$genome_file: $!";
while (my $row = $csv->getline ($fh)) {
    next if( $row->[0] =~ /^\#/);
    if ( ! defined $row->[3] ) {
	warn(join(",",@$row),"\n");
    }
    if( exists $orgs{$row->[0]} ) {
	warn("already stored a value for ", $row->[0], "\n");
    } else {
	$orgs{$row->[0]} = { 'strain' => $row->[1],
			     'family' => $row->[2],
			     'source' => $row->[3] };
    }
}
my %seen;
for my $t ( @target_dirs ) {
    opendir(D, "$outdir/$t") || die "Cannot open $outdir/$t";
    for my $file ( readdir(D) ) {
	next if $file =~ /\.sqlite/;
	my (@name) = split(/\_/,$file);
	my ($nm) = join(" ",$name[0],$name[1]);
	if( exists $orgs{$nm} ) {
	   # warn("saw $nm as expected for $t\n");
	    $seen{$nm}->{$t}++;
	}
    }
}

for my $nm ( keys %seen ) {
    for my $g ( @target_dirs ) {
	if( ! $seen{$nm}->{$g}  ) {
	    warn("no $g for $nm\n");
	} elsif ( $seen{$nm}->{$g} > 1 ) {
	    warn("Too many $g for $nm\n");
	} else {
	   # warn("ok $nm -> $g\n");
	}

    }
}

for my $sp ( keys %orgs ) {
    for my $g ( @target_dirs ) {
	if( ! exists $seen{$sp}->{$g} ) {
	    warn("did not see any $g for $sp\n");
	}
    }
}
