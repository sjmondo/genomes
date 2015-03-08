#! usr/bin/python
import os

num = 0
for file in os.listdir("final_combine/GFF"):
	if file.endswith(".gff3"):
		opfile = open("final_combine/GFF/" + file,'r')
		line = opfile.readline()
		unannotated = True
		for line in opfile:
			linearr = line.split()
			if len(linearr) < 3:
				continue
			if linearr[2] == "gene":
				unannotated = False
				break 
		if unannotated == True:
			fileroot = file[:-4]
			print fileroot
			num = num + 1
			os.rename("final_combine/GFF/" + file,"final_combine/no_annotation/" +file)  
			os.rename("final_combine/DNA/" + fileroot +"fasta", "final_combine/no_annotation/"+ fileroot + "fasta")     
		opfile.close
print num
