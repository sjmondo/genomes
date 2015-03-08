#!usr/bin/python

import os

directorylist = "final_combine/GFF","final_combine/DNA", "final_combine/pep", "final_combine/CDS"
for directory in directorylist:
	count = 0
	csvfile = open("lib/organisms.csv",'r')
	print "Missing in " + directory
	line = csvfile.readline()
	for line in csvfile:
		linearr = line.split(",")
		linearr[0] = linearr[0].strip('.')
		stripline = linearr[0].split()
		stripline = stripline[0] + ' ' + stripline[1]
		found = False
		for file in os.listdir(directory):
			fnamearr = file.split('.')
			fnamearr[0] = fnamearr[0].replace('_',' ')
			fnamestrip = fnamearr[0].split()
			fnamestrip = fnamestrip[0] + " " + fnamestrip[1]
			if stripline == fnamestrip:
				found = True
		if found == False:
			count = count + 1
			print linearr[0] + " " +linearr[2] +" " +  linearr[3]
	print count
	csvfile.close()
