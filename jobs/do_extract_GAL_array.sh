#PBS -q js -j oe -l nodes=1:ppn=1,walltime=24:00:00 -N GAL_extract_pep
module load perl

N=$PBS_ARRAYID

INFILE=gff_list
if [ ! $N ]; then
 N=$1
fi

if [ ! $N ]; then
 echo "Need a PBS_ARRAYID or cmdline number"
 exit;
fi

if [ ! -f $INFILE ]; then
 ls final_combine/GFF/*.gff3 > $INFILE
fi

line=`head -n $N $INFILE  | tail -n 1`
perl scripts/extract_pep_GAL_arrayjob.pl --gff $line --dna final_combine/DNA
