#!usr/bin/python

import os
print '{0:<75} {1:<12} {2:<11}'.format("Name","Total Genes", "Average Length")
for files in os.listdir("final_combine/GFF/"):
	if files[-4:] == "gff3":		
		file  = open("final_combine/GFF/" + files,'r')
		length_total = 0
		total = 0
		for line in file:
			linearr = line.split()
			if len(linearr)> 3 and linearr[2] == "gene":
				length_total = length_total +int(linearr[4]) - int(linearr[3])
				total = total + 1
		print '{0:<75} {1:<12} {2:<11}'.format( files[:-4], total, length_total/total)

				
