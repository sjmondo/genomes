#!env perl
use strict;
use warnings;
my $debug = 1;
my $debug_one = 0;
my $force = 0;
my $dir = shift || "download";
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
	warn("sp is $dir/$f/$sp\n") if $debug;
	opendir(SP,"$dir/$f/$sp") || die "$dir/$f/$sp $!";
	for my $file ( readdir(SP) ) {
		warn("file is $file\n");
	    if( $file =~ /(\S+\.aa\.fasta).gz$/) {
		my $stem = $1;
		warn "stem is $stem\n";
		next if -f "$p_odir/$stem";
		print("zcat $dir/$f/$sp/$file | ",
		      'perl -p -e \'s/^>(\w+)\|(\S+)\|(\d+)\|(\S+)/>$2|$2_$3 $4/\' > ',"$p_odir/$stem\n");
            } elsif ( $file =~ /(\S+\.CDS\.fasta).gz$/) {
		my $stem = $1;
                next if -f "$c_odir/$stem";
                print("zcat $dir/$f/$sp/$file | ",
                      'perl -p -e \'s/^>(\w+)\|(\S+)\|(\d+)\|(\S+)/>$2|$2_$3 $4/\' > ',"$c_odir/$stem\n");
	    } elsif ( $file =~ /(\S+\.assembly\.fasta).gz$/) {
		my $stem = $1;
		$stem =~ s/\.assembly//;
		next if -f "$d_odir/$stem";
		print("zcat $dir/$f/$sp/$file > $d_odir/$stem\n");
	    } elsif ( $file =~ /(\S+\.gff3).gz$/) {
		my $stem = $1;
		my @name = split(/\./,$stem);
	 	pop @name;
		if( $name[-1] =~ /v\d+/ ) {
		 pop @name;
		}
		my $n = pop @name;
		next if !$force && -f "$g_odir/$stem";
		open(my $in => "zcat $dir/$f/$sp/$file |") || die "cannot open $dir/$f/$sp/$file: $!";
		open(my $out => ">$g_odir/$stem")|| die "cannot open $g_odir/$stem: $!";
                my $no_ninth_name;
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
			if( exists $ninth{'Name'} ) {
			    my $val = $ninth{'Name'};
			    if( $val =~ /jgi\.p\|(\S+)\|(\d+)\|?$/ ) {
				$val = "$1|$1\_$2";
			    }
			    $ninth{'Name'} = $val;
			    push @row, join(";", map { sprintf("%s=%s", $_,
							   $ninth{$_}) }
					@order);
			} else {
			  push @row, $last;
			  $no_ninth_name = 1;
			  last;
			}
			$_= join("\t",@row)."\n";
		    } 
		    print $out $_;
		}
		close($in);
		close($out);
		if( $no_ninth_name ) {
		 warn("zcat $dir/$f/$sp/$file | perl scripts/gtf2gff3_3level.pl -p $n > $g_odir/$stem\n");
		 `zcat $dir/$f/$sp/$file | perl scripts/gtf2gff3_3level.pl -p $n > $g_odir/$stem`;
		}
	    }
	}
#	last if $debug_one;
    }
}
