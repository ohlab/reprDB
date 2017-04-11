#   ReprDB compilation pipeline
#   Copyright (C) 2017 Nicole Gay

#   This program is free software: you can redistribute it and/or modify
#   it under the terms of the GNU General Public License as published by
#   the Free Software Foundation, either version 3 of the License, or
#   any later version.

#   This program is distributed in the hope that it will be useful,
#   but WITHOUT ANY WARRANTY; without even the implied warranty of
#   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#   GNU General Public License for more details.

#   You should have received a copy of the GNU General Public License
#   along with this program.  If not, see <http://www.gnu.org/licenses/>.

import sys, math

#running from terminal or command line: 
#splitJobs.py file.txt $LINES $JOB_NUM

accns = sys.argv[1] #complete list of organisms (GenBank acc or organism name)
lineCount = sys.argv[2] #line count of file.txt
jobNum = sys.argv[3] #number of jobs to submit

def split():
	count = int(lineCount)
	jobs = int(jobNum)
	linesPer = int(math.ceil(count/jobs))
	line = int(0)
	fileSuffix = 1
	while (line < count):
		if (line + linesPer) < count:
			flName = "GenBankAcc_" + str(fileSuffix)
			fileName = open(flName, 'w')
			for n in range(line,(linesPer + line)):
				lineContent = open(accns).readlines()[n]
				fileName.write(lineContent)
		else:
			flName = "GenBankAcc_" + str(fileSuffix)
			fileName = open(flName, 'w')
			for n in range(line,count):
				lineContent = open(accns).readlines()[n]
				fileName.write(lineContent)
			
		fileSuffix = fileSuffix + 1
		line = line + linesPer
		
	print (fileSuffix - 1 )

split()
