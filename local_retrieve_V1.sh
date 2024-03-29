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

echo
echo "Downloading genomes... This may take a while."

# Set up the folders and output files
mkdir ${outdir}/_interim

# Throughout this script, there are while loops with an $ITER max iteration condition of 5. 
# This is to make 5 attempts of downloading a file before giving up because I frequently see Entrez errorring out even when it's very possible to fetch a file for that accession
 
touch ${outdir}/all_lengths.txt
touch ${outdir}/failed_downloads.txt

cd ${outdir}

for n in `cat GenBankAcc.txt`; do # iterate through lines of GenBankAcc.txt

	# Reset variables
	ERROR=0
	NEW_HEAD=null
	COUNT=null
	CHECK=null
	GENOME_LENGTH=null
	
	if [[ $n != *,* ]]; then

		echo $n
	
		#1: Retrieve FASTA file
		########################## 
		esearch -db nuccore -query "$n[ACCN]" | efetch -format fasta > $n.fasta
		sleep 5
		COUNT=`wc -c < $n.fasta | sed 's/^ *//' | sed 's/ .*//'`
		
		ITER=1
		while [ "$COUNT" -lt 2 ] || [ "$ITER" -lt 5 ]; do
			esearch -db nuccore -query "$n[ACCN]" | efetch -format fasta > $n.fasta
			sleep 5
			COUNT=`wc -c < $n.fasta | sed 's/^ *//' | sed 's/ .*//'`
			ITER=$((ITER + 1))
		done
		
		if [ "$COUNT" -lt 2 ]; then 
			printf "GenBank Accession $n failed to compile FASTA\n" >> failed_downloads.txt
			rm -f $n.fasta
			ERROR=1
		else
			awk '!/^>/ { printf "%s", $0; n = "\n" } /^>/ { print n $0; n = "" } END { printf "%s", n }' $n.fasta > tmp.$n.nolines.fasta	#create a temporary file that merges each contig into a single line
			head -1 $n.fasta > new$n.fasta	#paste header of $n.fasta into new fasta file
			sed '/^$/d' tmp.$n.nolines.fasta | grep -h -v ">" | perl -pe 's/\n/NNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNN/' >> new$n.fasta
			echo >> new$n.fasta	#add an empty line at the end of the fasta file
			rm $n.fasta	
			rm tmp.$n.nolines.fasta
		fi
		#---------------------------------------
		#Output: new$n.fasta (bad header)
		

		#2: Retrieve XML file and compile lineage string
		########################## 
		# Construct the taxonomy string for each species and add it to the table
		esearch -db nuccore -query "$n[ACCN]" | efetch -format gp | head -50 > info
		sleep 5
		
		COUNT=`wc -c < info | sed 's/^ *//' | sed 's/ .*//'`
		
		ITER=1
		while [ "$COUNT" -lt 2 ] || [ "$ITER" -lt 5 ]; do
			esearch -db nuccore -query "$n[ACCN]" | efetch -format gp | head -50 > info
			sleep 5
			COUNT=`wc -c < info | sed 's/^ *//' | sed 's/ .*//'`
			ITER=$((ITER + 1))
		done
		
		if [ "$COUNT" -lt 2 ]; then 
			rm info
			printf "GenBank Accession $n failed to fetch XML file\n" >> failed_downloads.txt
			ERROR=2
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
			
			rm info org_messy sm_string tight
		fi
		#---------------------------------------
		#Output: lineage.txt (file with lineage string)
		
		
		#3: Rehead FASTA file and add to all_lengths.txt
		########################## 
		if [ $ERROR == "0" ]; then
			GENOME_LENGTH=`sed '1d' new$n.fasta | sed 's/N//' | wc -m` #determine genome length
			if [ "$GENOME_LENGTH" -lt 2 ]; then
				printf "GenBank Accession $n failed to compile FASTA\n" >> failed_downloads.txt
				rm -f new$n.fasta
				ERROR=1
			else	
				NEW_HEAD=`cat lineage.txt`
				CHECK=`echo $?`
				if [ $CHECK == "0" ]; then					
					printf ">ACCN:$n|$NEW_HEAD\n" > $n.fasta
					sed '1d' new$n.fasta >> $n.fasta
					printf ">ACCN:$n|$NEW_HEAD\t$GENOME_LENGTH\n" >> all_lengths.txt #add lineage string and genome length to all_lengths.txt
					mv $n.fasta _interim #move .fasta file to _interim
					rm lineage.txt
					rm new$n.fasta	
				else 
					ERROR=3
					printf "GenBank Accession $n can't access lineage.txt\n" >> failed_downloads.txt
					rm -f new$n.fasta
					printf "GenBank Accession $n generated errors. Associated files removed\n" >> failed_downloads.txt
				fi
			fi
		else
			rm -f new$.fasta
			printf "GenBank Accession $n generated errors. Associated files removed\n" >> failed_downloads.txt
		fi
		#---------------------------------------
		#Output: final .fasta and line in all_lengths.txt
		
	else #else if there are multiple accessions...
		
		echo $n | tr ',' '\n' | sed '/^$/d' > ACC.txt #make a list of accession numbers
		h=`head -1 ACC.txt`
		mkdir _temp


		#1: FOR EACH retrieve FASTA file, concatenate, get genome length
		########################## 
		for x in `cat ACC.txt`; do # iterate through the list

			echo $x
			
			esearch -db nuccore -query "$x[ACCN]" | efetch -format fasta > $x.fasta
			sleep 5
			COUNT=`wc -c < $x.fasta | sed 's/^ *//' | sed 's/ .*//'`
		
			ITER=1
			while [ "$COUNT" -lt 2 ] || [ "$ITER" -lt 5 ]; do
				esearch -db nuccore -query "$x[ACCN]" | efetch -format fasta > $x.fasta
				sleep 5
				COUNT=`wc -c < $x.fasta | sed 's/^ *//' | sed 's/ .*//'`
				ITER=$((ITER + 1))
			done
			
			if [ "$COUNT" -lt 2 ]; then 
				printf "GenBank Accession $x failed to fetch FASTA file (partial accession)\n" >> failed_downloads.txt
				rm ${x}.fasta
			else
				awk '!/^>/ { printf "%s", $0; n = "\n" } /^>/ { print n $0; n = "" } END { printf "%s", n }' ${x}.fasta > tmp.${x}.nolines.fasta	#create a temporary file that merges each contig into a single line
				head -1 ${x}.fasta > new${x}.fasta	#paste header of $f.fasta into new fasta file
				sed '/^$/d' tmp.${x}.nolines.fasta | grep -h -v ">" | perl -pe 's/\n/NNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNN/' >> new$x.fasta	#remove headers of each contig and concatenate the contigs with NNN spacers between them
				echo >> new${x}.fasta # add an empty line at the end of the fasta file
				rm ${x}.fasta
				mv new${x}.fasta $x.fasta
				mv $x.fasta _temp
				rm tmp.$x.nolines.fasta	
			fi
			
		done
		#---------------------------------------
		#Output: $x.fasta files in _temp
			
		# Concatenate all files in the "_temp" folder
		cd _temp
		cat *.fasta > $h.tmp.fa
		# clean it up
		head -1 $h.tmp.fa > $h.tmp.fasta #paste header of $h.tmp.fa into new fasta file
		grep -h -v ">" $h.tmp.fa | perl -pe 's/\n//g' >> $h.tmp.fasta #remove headers of each contig and concatenate the contigs with NNN spacers between them
		echo >> $h.tmp.fasta #add an empty line at the end of the fasta file
		mv $h.tmp.fasta $h.fasta
			
		mv $h.fasta .. #move .fasta file back into main directory
		cd .. #move back into main directory
		rm -rf _temp
		#---------------------------------------
		#Output: concatentated .fasta file (bad header)
	
		
		#2: FOR JUST THE FIRST ONE retrieve xml file and compile lineage string
		########################## 
		# Construct the taxonomy string for each species and add it to the table
		esearch -db nuccore -query "$h[ACCN]" | efetch -format gb | head -50 > info
		sleep 5
		COUNT=`wc -c < info | sed 's/^ *//' | sed 's/ .*//'`
		
		ITER=1
		while [ "$COUNT" -lt 2 ] || [ "$ITER" -lt 5 ]; do
			esearch -db nuccore -query "$h[ACCN]" | efetch -format gb | head -50 > info
			sleep 5
			COUNT=`wc -c < info | sed 's/^ *//' | sed 's/ .*//'`
			ITER=$((ITER + 1))
		done
		
		if [ "$COUNT" -lt 2 ]; then 
			rm info
			printf "GenBank Accession $h failed to fetch XML file\n" >> failed_downloads.txt
			ERROR=1
		else
			sed '/REFERENCE/,$d' info | sed -e '1,/SOURCE/d' -e 's/^ *//' > org_messy
			head -1 org_messy | sed -e 's/ORGANISM//' -e 's/^ *//' > sm_string # species name
			sed '1d' org_messy | tr -d '\n' | sed -e 's/; /;/g' -e 's/\./;/' > tight
			cat sm_string >> tight
			tr -d '\n' < tight | sed 's/ /_/g' | sed "s/'//g" | sed 's/;_/:/g' > lineage.txt # lineage string
			
			rm info org_messy sm_string tight
		fi
		#---------------------------------------
		#Output: lineage.txt (file with lineage string)


		#3: rehead FASTA file and add to all_lengths.txt
		########################## 	
		if [ $ERROR == "0" ]; then	
			COUNT=`wc -c < lineage.txt | sed 's/^ *//' | sed 's/ .*//'`
			if [ "$COUNT" -lt 2 ]; then 
				printf "GenBank Accession $h failed to fetch XML file\n" >> failed_downloads.txt
				rm lineage.txt
			else
				NEW_HEAD=`cat lineage.txt`
				CHECK=`echo $?`
				if [ $CHECK == "0" ]; then 
					printf ">ACCN:$h|$NEW_HEAD\n" > new$h.fasta
					sed '1d' $h.fasta >> new$h.fasta
					rm $h.fasta
					mv new$h.fasta $h.fasta
					GENOME_LENGTH=`sed '1d' $h.fasta | sed 's/N//' | wc -m` #determine genome length
					if [ "$GENOME_LENGTH" -lt 2 ]; then
						printf "GenBank Accession $n failed to compile FASTA\n" >> failed_downloads.txt
						rm $h.fasta
						ERROR=1
					else		
						printf ">ACCN:$h|$NEW_HEAD\t$GENOME_LENGTH\n" >> all_lengths.txt #add lineage string and genome length to all_lengths.txt
						mv $h.fasta _interim #move .fasta file to _interim
						rm lineage.txt
					fi
				else
					printf "GenBank Accession $h can't access lineage.txt\n" >> failed_downloads.txt
					rm $h.fasta
					printf "GenBank Accession $h generated errors. Associated files removed\n" >> failed_downloads.txt
				fi
			fi
		else
			printf "GenBank Accession $h generated errors. Associated files removed\n" >> failed_downloads.txt
		fi
		#---------------------------------------
		#Output: final .fasta and line in all_lengths.txt
		
		rm ACC.txt	
	fi
done 

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

rm -rf _interim GenBankAcc.txt

printf "\nDone! Look in compiled_genomes for the concatenated .fa files and all_lengths.txt!\n\n"

