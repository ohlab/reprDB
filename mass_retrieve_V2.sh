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
# Updated 19 March 2019

infile=$1
outdir=`dirname $infile`
cd $outdir

echo 
echo "This script is for the download of genomes by GenBank accession. Please see Version 2 for download by organism name."
echo

# Check if the user input is a valid file name
if [ -f "$infile" ]; then 
	head -1 ${infile} > heads.txt
elif [ "$infile" == "" ]; then
	echo "No input file provided. Please type the name of the input file after your call to this script."
	exit
else
	echo "File ${infile} not found."
	exit
fi

LOOP1=true
while $LOOP1
do
	printf "\nType the number corresponding to the input file type:\n1: NCBI .txt file\n2: List of organism names\n3: Quit\n"
	read -n 1 INPUT
	echo
	if [ $INPUT == 1 ]
	then
		LOOP1=false
		# Retrieve the organism names from the NCBI table
		ORG_COL=`tr '\t' '\n' < heads.txt | nl | grep Organism/Name | cut -f 1`
		rm heads.txt
		cut -f $ORG_COL $infile | sed 's/ /_/g' | sed '/#Organism/d' > all_species.txt
		
		# Clean up the target species list
		cut -f 1 all_species.txt | cut -f1,2 -d'_' | sort | uniq > long_species.txt
		grep "_sp\." long_species.txt | sed 's/_.*//' > unnamed_species.txt #SAVE FOR LATER
		sed '/\./d' long_species.txt > simple_species.txt
		rm long_species.txt
		
		for a in `cat unnamed_species.txt`
		do
			grep "$a sp\." $infile | cut -f 1 | sed 's/ /_/g' >> simple_species.txt
		done
		
	elif [ $INPUT == 2 ]
	then
		LOOP1=false
		# skip to looping through organism name
		cat $infile > all_species.txt
		
		# Clean up the target species list
		cut -f 1 all_species.txt | cut -f1,2 -d'_' | sort | uniq > long_species.txt
		grep "_sp\." long_species.txt | sed 's/_.*//' > unnamed_species.txt #SAVE FOR LATER
		sed '/\./d' long_species.txt > simple_species.txt
		rm long_species.txt
		
		for a in `cat unnamed_species.txt`
		do
			grep "$a sp\." $infile | cut -f 1 | sed 's/ /_/g' >> simple_species.txt
		done
		
	elif [ $INPUT == 3 ]
	then
		printf "\n\nTerminating program...\n\n"
		exit
	else
		printf "\n\nInvalid entry. Type a number 1-4.\n"
	fi
done

ASKED=`wc -l < all_species.txt | sed 's/^ *//' | sed 's/ .*//'`
FETCHED=`wc -l < simple_species.txt | sed 's/^ *//' | sed 's/ .*//'`

echo "Number of species requested:	$ASKED"
echo "Number of species processed:	$FETCHED"

# Set up the folders and output files
mkdir _interim
 
# Split GenBankAcc.txt into number of specified jobs
LINES=`wc -l < simple_species.txt | sed 's/^ *//' | sed 's/ .*//'`
END=`python splitJobs.py simple_species.txt $LINES $JOB_NUM` #generate JOB_NUM of chunks of GenBank accessions, each in a different file
sleep 3
printf "Number of jobs generated: $END\n\n"

export ${outdir}

# Job array: for each chunk of accessions, download and edit the .fasta file and output all_lengths.txt
########################## mass_retrieve.qsub
JOB1=`qsub mass_retrieve_V2.qsub -t 1-$END -d $PWD`
if [ `echo $?` == 0 ]
then
	echo $JOB1
	printf "\nJob array submitted! Please wait for the directory to update. Then check failed_downloads_*.txt for errors.\n\n"
fi
########################## mass_retrieve.qsub
#OUTPUT: FASTA files with correct headers; all_lengths.txt
