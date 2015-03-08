#!usr/bin/python

import os
from Bio import SeqIO
from Bio.SeqRecord import SeqRecord

for files in os.listdir("final_combine/CDS/"):
	infile = "final_combine/CDS/" + files
	output = "final_combine/converted_pep/" + files[:-9] + "aa.fasta"

	records = SeqIO.parse(infile, 'fasta')

	proteins = []
	for rec in records:
		translated_rec = SeqRecord(seq = rec.seq.translate(), id = rec.id, description = rec.description)
		proteins.append(translated_rec)
	SeqIO.write(proteins, open(output, 'w'), 'fasta')
