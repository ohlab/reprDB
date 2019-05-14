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

infile=$1
outdir=`dirname $infile`

echo 
echo "This script is for the download of genomes by GenBank accession. Please see Version 2 for download by organism name."
echo

# Check if the user input is a valid file name
if [ -f "$infile" ]; then 
	head -1 ${infile} > ${outdir}/heads.txt
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
	printf "Type the number corresponding to the input file type:\n1: PATRIC .txt file\n2: NCBI .nbr file\n3: List of GenBank accessions\n4: Quit\n"
	read -n 1 INPUT
	echo
	if [ $INPUT == 1 ]; then
		LOOP1=false
		# Retrieve the GenBank accessions from the PATRIC table
		colnum=`tr '\t' '\n' < ${outdir}/heads.txt | nl | grep 'GenBank Accessions$' | cut -f 1`
		cut -f ${colnum} ${infile} | sed -e '/^$/d' -e '1d' > ${outdir}/GenBankAcc.txt
	elif [ $INPUT == 2 ]; then
		LOOP1=false
		# Retrieve the GenBank accessions from the NCBI table
		cut -f 1 ${infile} | sed -e '1,2d' -e 's/,.*//' | sort -u -k1,1 > ${outdir}/NCBI_acc.txt
		printf "" > ${outdir}/GenBankAcc.txt
		for NCBI_acc in `cat ${outdir}/NCBI_acc.txt`
		do
			grep $NCBI_acc $infile | cut -f 2 | tr "\n" "," | sed '$ s/.$//' > ${outdir}/GenBank.txt
			GEN_ACC=`cat ${outdir}/GenBank.txt`
			printf "$GEN_ACC\n" >> ${outdir}/GenBankAcc.txt
		done
		rm ${outdir}/GenBank.txt
		rm ${outdir}/NCBI_acc.txt
	elif [ $INPUT == 3 ]; then
		LOOP1=false
		# skip to looping through accessions
		cat $infile > ${outdir}/GenBankAcc.txt
	elif [ $INPUT == 4 ]; then
		printf "\n\nTerminating program...\n\n"
		exit
	else
		printf "\n\nInvalid entry. Type a number 1-4.\n"
	fi
done
rm -f ${outdir}/heads.txt

printf "\nOne moment please...\n\n"

# Set up the folders and output files
mkdir ${outdir}/_interim
 
# Split GenBankAcc.txt into number of specified jobs
LINES=`wc -l < ${outdir}/GenBankAcc.txt |sed 's/^ *//' | sed 's/ .*//'`
END=`python splitJobs.py ${outdir}/GenBankAcc.txt $LINES $JOB_NUM` #generate JOB_NUM of chunks of GenBank accessions, each in a different file
sleep 3
printf "Number of jobs generated: $END\n\n"
rm ${outdir}/GenBankAcc.txt

# export ${outdir}

# Job array: for each chunk of accessions, download and edit the .fasta file and output all_lengths.txt
########################## mass_retrieve.qsub
JOB1=`qsub -t 1-$END -d $outdir mass_retrieve_V1.qsub`
if [ `echo $?` == 0 ]
then
	echo $JOB1
	printf "\nJob array submitted! Please wait for the directory to update. Then check failed_downloads_*.txt for errors.\n\n"
fi
########################## mass_retrieve.qsub
#OUTPUT: FASTA files with correct headers; all_lengths.txt

