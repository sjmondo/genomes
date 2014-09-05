#PBS -l nodes=1:ppn=1,walltime=24:00:00 -q js  -j oe
module load perl

perl scripts/genbank2files.pl
