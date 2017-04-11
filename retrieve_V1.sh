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

# Nicole Gay 
# SSP 2016
# 9 Aug 2016

# Have the user specify the input
printf "\nThis script is for the download of genomes by GenBank accession.\nPlease see Version 2 for download by organism name.\n"

# Make the user-defined file name a variable
printf "\n"
read -p "Type the name of the file (including extension). Then press ENTER: `echo $'\n> '`" FILE_NAME
printf "\n"

# Check if the user input is a valid file name in the PWD
head -1 ${FILE_NAME} > heads.txt
if [ `echo $?` == 0 ]
then
	continue
else
	printf "Terminating program...\n\n"
	exit
fi

# Get the number of chunks
printf "Enter the number of jobs you would like to submit to the cluster (integer < 100) or type 'help' for an explanation: "
LOOP=true
while $LOOP
do
	read JOB_NUM
	
	if [ $JOB_NUM == "help" ]
	then
		printf "\nThis number specifies how many chunks into which the requested accessions will be split in order to submit jobs in parallel. A greater number will result in shorter job completion. However, too high of a number will overload the NCBI Entrez server from which files are fetched.\n\n"
		printf "Enter an integer less than 100: "
	elif [[ $JOB_NUM = *[A-z]* ]]
	then
		printf "\nInvalid entry. Enter an integer less than 100: "
	elif [ $JOB_NUM -gt 100 ]
	then
		printf "\nInvalid entry. Enter an integer less than 100: "
	else
		LOOP=false
	fi
done

LOOP1=true
while $LOOP1
do
	printf "\nType the number corresponding to the input file type:\n1: PATRIC .txt file\n2: NCBI .nbr file\n3: List of GenBank accessions\n4: Quit\n"
	read -n 1 INPUT
	printf "\n"
	if [ $INPUT == 1 ]
	then
		LOOP1=false
		# Retrieve the GenBank accessions from the PATRIC table
		colnum=`tr '\t' '\n' < heads.txt | nl | grep 'GenBank Accessions$' | cut -f 1`
		cut -f ${colnum} ${FILE_NAME} | sed -e '/^$/d' -e '1d' > GenBankAcc.txt
	elif [ $INPUT == 2 ]
	then
		LOOP1=false
		# Retrieve the GenBank accessions from the NCBI table
		cut -f 1 ${FILE_NAME} | sed -e '1,2d' -e 's/,.*//' | sort -u -k1,1 > NCBI_acc.txt
		printf "" > GenBankAcc.txt
		for NCBI_acc in `cat NCBI_acc.txt`
		do
			grep $NCBI_acc $FILE_NAME | cut -f 2 | tr "\n" "," | sed '$ s/.$//' > GenBank.txt
			GEN_ACC=`cat GenBank.txt`
			printf "$GEN_ACC\n" >> GenBankAcc.txt
		done
		rm GenBank.txt
		rm NCBI_acc.txt
	elif [ $INPUT == 3 ]
	then
		LOOP1=false
		# skip to looping through accessions
		cat $FILE_NAME > GenBankAcc.txt
	elif [ $INPUT == 4 ]
	then
		printf "\n\nTerminating program...\n\n"
		exit
	else
		printf "\n\nInvalid entry. Type a number 1-4.\n"
	fi
done
rm -f heads.txt

printf "\nOne moment please...\n\n"

# Set up the folders and output files
mkdir _interim
 
# Split GenBankAcc.txt into number of specified jobs
LINES=`wc -l < GenBankAcc.txt |sed 's/^ *//' | sed 's/ .*//'`
END=`python splitJobs.py GenBankAcc.txt $LINES $JOB_NUM` #generate JOB_NUM of chunks of GenBank accessions, each in a different file
sleep 3
printf "Number of jobs generated: $END\n\n"
rm GenBankAcc.txt

# Job array: for each chunk of accessions, download and edit the .fasta file and output all_lengths.txt
########################## mass_retrieve.qsub
JOB1=`qsub mass_retrieve_V1.qsub -t 1-$END -d $PWD`
if [ `echo $?` == 0 ]
then
	echo $JOB1
	printf "\nJob array submitted! Please wait for the directory to update. Then check failed_downloads_*.txt for errors.\n\n"
fi
########################## mass_retrieve.qsub
#OUTPUT: FASTA files with correct headers; all_lengths.txt
