#PBS -q js -j oe -l nodes=1:ppn=1,walltime=24:00:00 -N GAL_extract_pep
module load perl
perl scripts/extract_pep_GAL.pl >& extract_pep.log
