#!/usr/bin/perl -w
use strict;
use Bio::SeqIO;
use File::Spec;
use Getopt::Long;
#module load GAL
my $force = 0;
my $debug = 0;
my $dir = "final_combine";
my $pepdir = File::Spec->catfile($dir,"pep");

GetOptions('force!'   => \$force,
	   'pep:s'    => \$pepdir,
	   'v|debug!' => \$debug,
    );

opendir(PEP, $pepdir) || die $!;
my %seen;
my %f;
for my $file ( readdir(PEP) ) {
    next unless ( $file =~ /(\S+)\.aa.fasta$/);
    my $stem= $1;
    next if $file =~ /v(\d+)\./;
    $stem =~ s/(var|f|sp)\./$1/g;
    my ($first) = split(/\./,$stem);
    my ($genus,$species) = split(/_/,$first);    
    my $prefix = substr($genus,0,1).substr($species,0,3);
    $seen{$prefix}++;
    $f{$file} = $prefix;
    warn("stem $stem for $file [$genus] [$species] $prefix\n");
}
for my $p ( sort keys %seen ) {
    if ( $seen{$p} > 1 ) {
	warn("$p has $seen{$p} copies, not unique\n");
    }
}
for my $file ( keys %f ) {
    my $in = Bio::SeqIO->new(-format => 'fasta',
			     -file   => File::Spec->catfile($pepdir,$file));
    my @seqs;
    while( my $s = $in->next_seq ) {
	if( $s->display_id =~ /(\S+)\|(\S+)/ ) {
	    last;
	} else {
	    $s->display_id(sprintf("%s|%s",$f{$file},$s->display_id));
	}
	push @seqs, $s;
    }
    if( @seqs ) {
	my $out = Bio::SeqIO->new(-format => 'fasta',
				  -file   => ">".File::Spec->catfile($pepdir,$file.".new"));
	$out->write_seq(@seqs);
    }
}

