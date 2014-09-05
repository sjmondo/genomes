#!env perl
#module load GAL
my $exe = '/opt/GAL/0.2.2/bin/gal_protein_sequence';
my $dir = "final_combine";
my $gffdir = File::Spec->catfile($dir,"GFF");
opendir(DIR,$gffdir) || die "$gffdir: $!";
my $dnadir = File::Spec->catfile($dir,"DNA");
my $pepdir = File::Spec->catfile($dir,"pep");
foreach my $file ( readdir(DIR) ) {
    next unless $file =~ /(\S+)\.gff3/;
    my $base = $1;
    my ($genus,$species) = split(/\_/,$base);
    my $pref = substr($genus,0,1).substr($species,0,3);
    `$exe $gffdir/$file $dnadir/$base.fasta | perl -p -e 's/^>/>$pref|' > $pepdir/$base.aa.fasta`
    last;
}
