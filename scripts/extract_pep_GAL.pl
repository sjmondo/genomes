#!env perl
use File::Spec;
use Getopt::Long;
#module load GAL
my $force = 0;
my $debug = 0;
my $exe = '/opt/GAL/0.2.2/bin/gal_protein_sequence';
my $dir = "final_combine";
my $gffdir = File::Spec->catfile($dir,"GFF");
my $dnadir = File::Spec->catfile($dir,"DNA");
my $pepdir = File::Spec->catfile($dir,"pep");

GetOptions('force!'   => \$force,
	   'exe:s'    => \$exe,
	   'gff:s'    => \$gffdir,
	   'dna:s'    => \$dnadir,
	   'pep:s'    => \$pepdir,
	   'v|debug!' => \$debug,
    );
opendir(DIR,$gffdir) || die "$gffdir: $!";
foreach my $file ( readdir(DIR) ) {
    next unless $file =~ /(\S+)\.gff3/;
    my $base = $1;
    my ($genus,$species) = split(/\_/,$base);
    my $pref = substr($genus,0,1).substr($species,0,3);
    next if ( -f "$pepdir/$base.aa.fasta" && ! $force );
    `$exe $gffdir/$file $dnadir/$base.fasta | perl -p -e 's/^>/>$pref|/' > $pepdir/$base.aa.fasta`;
}
