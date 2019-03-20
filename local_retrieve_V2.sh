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

# Throughout this script, there are while loops with an $ITER max iteration condition of 5.
# This is to make 5 attempts of downloading a file before giving up because I frequently see Entrez errorring out even when it's very possible to fetch a file for that accession
 
touch all_lengths.txt
touch failed_downloads.txt

for n in `cat simple_species.txt`; do # iterate through lines of simple_species.txt

	# Reset variables
	ERROR=0
	NEW_HEAD=null
	COUNT=null
	CHECK=null
	GENOME_LENGTH=null
	NAME=null

	NAME=`echo $g | sed 's/_/ /g'`
	esearch -db nuccore -query "$NAME[ORGN]" | efetch -format fasta > $g.fasta
	sleep 5
	COUNT=`wc -w < $g.fasta | sed 's/^ *//' | sed 's/ .*//'`
	if [ "$COUNT" -lt 2 ]; then 
		ERROR=1
		printf "Species $NAME failed to compile FASTA\n" >> failed_downloads.txt
		rm $g.fasta
	else
		awk '!/^>/ { printf "%s", $0; n = "\n" } /^>/ { print n $0; n = "" } END { printf "%s", n }' $g.fasta > tmp.$g.nolines.fasta	
		head -1 $g.fasta > new$g.fasta
		sed '/^$/d' tmp.$g.nolines.fasta | grep -h -v ">" | perl -pe 's/\n/NNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNN/' >> new$g.fasta
		echo >> new$g.fasta
		rm $g.fasta
		rm tmp.$g.nolines.fasta
		HEAD=`head -1 new$g.fasta`
		VAL=`echo $HEAD | grep -c "|gb|"`
		ACCN=`echo $HEAD | cut -f4 -d'|'`
		mv new$g.fasta $ACCN.fasta
		COUNT=`sed '1d' $ACCN.fasta | wc -c | sed 's/^ *//' | sed 's/ .*//'`
		if [ "$COUNT" -lt 2 ]; then
			ERROR=1
			printf "Species $NAME fetched a blank genome\n" >> failed_downloads.txt
			rm $ACCN.fasta	
		else 
			printf "$ACCN\n" >> accessions.txt
			mv $ACCN.fasta _interim #move .fasta file to _interim
		fi
	fi
done 
#OUTPUTS: fasta files with wrong headers in _interim and a list of accessions in PWD

#=========================================================================================

# Compiling lineage strings for every accession...

INC=0
touch headers.txt

for y in `cat accessions.txt`; do	
	esearch -db nuccore -query "$y[ACCN]" | efetch -format gp | head -50 > info
	sleep 5
	COUNT=`wc -c < info | sed 's/^ *//' | sed 's/ .*//'`
	if [ "$COUNT" -lt 2 ]; then 
		ERROR=1
		rm info
		printf "GenBank Accession $y failed to fetch XML file\n" >> failed_downloads.txt
	else	
		sed '/REFERENCE/,$d' info | sed -e '1,/SOURCE/d' -e 's/^ *//' > org_messy
		if [ `grep -n ORGANISM org_messy | cut -c1` != "1" ]; then
			sed '1d' org_messy > tmp
			rm org_messy
			mv tmp org_messy
		fi	
		head -1 org_messy | sed -e 's/ORGANISM//' -e 's/^ *//' > sm_string # species name
		sed '1d' org_messy | tr -d '\n' | sed -e 's/; /;/g' -e 's/\./;/' > tight
		cat sm_string >> tight
		tr -d '\n' < tight | sed 's/ /_/g' | sed "s/'//g" | sed 's/;_/:/g' > lineage.txt # lineage string
		
		LINEAGE=`cat lineage.txt`
		
		printf ">ACCN:$y|$LINEAGE\n" >> headers.txt
		rm -f info org_messy sm_string tight	
	fi
done

#OUTPUTS: headers for all accessions, complete with lineage string (headers.txt)

#=========================================================================================

# Reheading fasta files and compiling all_lengths.txt...

for q in `ls _interim/*.fasta`; do
	ACCN=`echo $q | sed 's/_interim\///' | sed 's/\.fasta//'`
	NEW_HEAD=`grep $ACCN headers.txt` # fetch correct header from 
	GENOME_LENGTH=`sed '1d' $q | sed 's/N//' | wc -c` # determine genome length
	if [ "$GENOME_LENGTH" -lt 2 ]; then 
		ERROR=1
		printf "GenBank Accession $ACCN failed to compile FASTA\n" >> failed_downloads.txt
		rm -f $q
	else
		printf ">ACCN:$n|$NEW_HEAD\t$GENOME_LENGTH\n" >> all_lengths.txt #add lineage string and genome length to all_lengths.txt
		printf "$NEW_HEAD\n" > tmp.$ACCN.fasta
		sed '1d' $q >> tmp.$ACCN.fasta
		rm -f $q
		mv tmp.$ACCN.fasta $ACCN.fasta
		mv $ACCN.fasta _interim 
	fi
done

if [ $ERROR != "0" ]; then
	printf "Species $NAME generated errors. Associated files removed\n" >> failed_downloads.txt
	rm -f $ACCN.fasta
	sed '/$ACCN/d' all_lengths.txt > tmp.txt
	rm all_lengths.txt
	mv tmp.txt all_lengths.txt
fi

#OUTPUTS: reheaded fasta files and all_lengths.txt

rm GenBankAcc
rm accessions.txt
rm lineage.txt

echo 
echo "Done downloading genomes. Cleaning up output folder..."

# concatenate FASTA files and clean up folder 

# Make a destination folder
mkdir -p compiled_genomes

cd _interim
INC=1
touch microbe_$INC.fa

# Concatenate FASTA files into <= 2.8 GB chunks
for each in `ls *.fasta`; do
	FILE_BYTES=`wc -c < $each | sed 's/^ *//' | sed 's/ .*//'`
	MASS_BYTES=`wc -c < microbe_$INC.fa | sed 's/^ *//' | sed 's/ .*//'`
	TOT=`expr $FILE_BYTES + $MASS_BYTES`
	MAX=2800000000 #2.8e9 B = 2.8 GB; CHANGE DEFAULT MAX SIZE HERE
	if [ $TOT -lt $MAX ]; then
		#append file to current chunk
		cat $each >> microbe_$INC.fa
	else
		#start new chunk with this file
		INC=$(( INC + 1 ))
		cat $each >> microbe_$INC.fa
	fi
	gzip $each
done
mv microbe_* ../compiled_genomes

cd .. 
mv all_lengths.txt compiled_genomes

printf "\nDone! Look in compiled_genomes for the concatenated .fa files and all_lengths.txt!\n\n"

