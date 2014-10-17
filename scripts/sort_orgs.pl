#!env perl
use strict;
use warnings;
use Text::CSV_XS;
open(my $fh => shift ) || die $!;
my $header = <$fh>;
print $header;
my @data;
my $csv = Text::CSV_XS->new ({ binary => 1, auto_diag => 1 });
while (my $row = $csv->getline ($fh)) {
    push @data, $row;
}
for my $row ( sort { $a->[2] cmp $b->[2] } @data ) {
    $csv->print(\*STDOUT,$row);
    print "\n";
}
