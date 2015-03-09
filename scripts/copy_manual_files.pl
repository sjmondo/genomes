#!env perl
use strict;
use warnings;
my $debug = 1;
my $debug_one = 0;
my $force = 0;
my $dir = shift || "../manual_genomes/download";
my $p_odir = shift || 'final_combine/pep';
my $g_odir = shift || 'final_combine/GFF';
my $d_odir = shift || 'final_combine/DNA';
my $c_odir = shift || 'final_combine/CDS';

mkdir("final_combine") unless -d "final_combine";
for my $d ( $p_odir, $g_odir, $d_odir, $c_odir ) {
 mkdir($d) unless -d $d;
}
opendir(DIR, $dir) || die $!;
for my $f ( readdir(DIR) ) {
    next if $f =~ /^\./;
    if( ! -d "$dir/$f" ) {
 	warn("not a dir ($dir/$f)\n");
	next;
    }
    opendir(FAM,"$dir/$f") || die $!;
    for my $sp ( readdir(FAM) ) {
	next if $sp =~ /^\./;
	next if ( ! -d "$dir/$f/$sp");
#	warn("sp is $dir/$f/$sp\n") if $debug;
	opendir(SP,"$dir/$f/$sp") || die "$dir/$f/$sp $!";
	for my $file ( readdir(SP) ) {
#		warn("file is $file\n");
	    if( $file =~ /((\S+)\.aa\.fasta).gz$/) {
		my $stem = $1;
		my $pref = &make_prefix($2);
		warn "stem is $stem\n";
		next if -f "$p_odir/$stem";
		print("zcat $dir/$f/$sp/$file | perl -p -e 's/>/>$pref|/' > $p_odir/$stem\n");
            } elsif ( $file =~ /((\S+)\.CDS\.fasta).gz$/) {
		my $stem = $1;
		my $pref = &make_prefix($2);
                next if -f "$c_odir/$stem";
		print("zcat $dir/$f/$sp/$file | perl -p -e 's/>/>$pref|/' > $c_odir/$stem\n");
	    } elsif ( $file =~ /((\S+)\.assembly\.fasta).gz$/) {
		my $stem = $1;
		my $pref = &make_prefix($2);
		$stem =~ s/\.assembly//;

		next if -f "$d_odir/$stem";
		print("zcat $dir/$f/$sp/$file |  perl -p -e 's/>/>$pref|/' > $d_odir/$stem\n");
	    } elsif ( $file =~ /(\S+\.gff3).gz$/) {
		my $stem = $1;
		next if !$force && -f "$g_odir/$stem";
		open(my $in => "zcat $dir/$f/$sp/$file |") || die "cannot open $dir/$f/$sp/$file: $!";
		open(my $out => ">$g_odir/$stem")|| die "cannot open $g_odir/$stem: $!";
		while(<$in>) {
		    last if /##FASTA/;
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
sub make_prefix {
    my $stem = shift @_;
    $stem =~ s/\.([_.])/$1/g;
    $stem =~ s/\.v\d+//;
    my @parts = split(/\./,$stem);
    my ($genus,$species) = split(/_/,$parts[0]);
    my $pref;
    if( @parts > 1 ) {
        $pref = $parts[1];
    } else {
        $pref = substr($genus,0,1).substr($species,0,3);
    }
    $pref;
}

