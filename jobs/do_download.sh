#PBS -j oe -N download_genbank
module load perl

perl scripts/download_genbank_eutil.pl lib/organisms.csv &> download.log

