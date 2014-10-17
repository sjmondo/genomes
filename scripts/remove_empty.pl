#!env perl
use strict;
use warnings;
use Bio::SeqIO;
use File::Copy qw(move);
use Getopt::Long;

my $min_length = 0;

my $ext = 'fasta';
my $debug = 0;
my $odir;
GetOptions
    ('ext:s'     => \$ext, # extension of file
     'o|odir:s'  => \$odir,
     'v|debug:s' => \$debug,
     'l|len:i'   => \$min_length,
    );

my $dir = shift|| die "need an input dir";
if( $odir && ! -d $odir ) { mkdir($odir) }

opendir(DIR, $dir) || die "cannot open $dir: $!";
for my $file ( readdir(DIR) ) {
    next unless $file =~ /(\S+)\.\Q$ext\E$/;
    my $stem = $1;
    my $out;
    if( $odir && $odir ne $dir ) {
	$out = Bio::SeqIO->new(-format => 'fasta',
			       -file   => ">$odir/$file");
    } else {
	$odir = undef;
	$out = Bio::SeqIO->new(-format => 'fasta',
			       -file   => ">$dir/$file.new");
    }
    my $in = Bio::SeqIO->new(-format => 'fasta',
			     -file   => "$dir/$file");
    while( my $s = $in->next_seq ){
	next if $s->length < $min_length;
	$out->write_seq($s);
    }
    
    if( ! $odir && ! $debug ) {
	copy("$dir/$file","$dir/$file.old");
	move("$dir/$file.new", "$dir/$file");
    }
}
