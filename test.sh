#!/bin/bash

#   PanDB compilation pipeline
#   Copyright (C) 2017 Wei Zhou

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

#=========args=========
# $1=kingdom
# $2=number of PBS jobs
# $3=qsub resource string
#======================


JOB_NUM=1

# checking PATRIC .txt file
FILE_NAME="test/PATRIC_genome.txt"
head -1 ${FILE_NAME} > heads.txt
colnum=`tr '\t' '\n' < heads.txt | nl | grep 'GenBank Accessions$' | cut -f 1`
cut -f ${colnum} ${FILE_NAME} | sed -e '/^$/d' -e '1d' > GenBankAcc.txt

if cmp -s test/GenBankAcc1.txt GenBankAcc.txt ; then
   echo "PATRIC .txt checked" > test_result
else
   echo "PATRIC .txt not working properly" > test_result
fi


# checking .nbr file
FILE_NAME="test/NCBI_viral.nbr"
cut -f 1 ${FILE_NAME} | sed -e '1,2d' -e 's/,.*//' | sort -u -k1,1 > NCBI_acc.txt
printf "" > GenBankAcc.txt
for NCBI_acc in `cat NCBI_acc.txt`
do
	grep $NCBI_acc $FILE_NAME | cut -f 2 | tr "\n" "," | sed '$ s/.$//' > GenBank.txt
	GEN_ACC=`cat GenBank.txt`
	printf "$GEN_ACC\n" >> GenBankAcc.txt
done

if cmp -s test/GenBankAcc2.txt GenBankAcc.txt ; then
   echo "NCBI .nbr checked"  >> test_result
else
   echo "NCBI .nbr not working properly"  >> test_result
fi
rm GenBank.txt
rm NCBI_acc.txt
rm -f heads.txt

# checking spliting
LINES=`wc -l < GenBankAcc.txt |sed 's/^ *//' | sed 's/ .*//'`
END=`python splitJobs.py GenBankAcc.txt $LINES $JOB_NUM`
if cmp -s test/GenBankAcc_1 GenBankAcc_1 ; then
   echo "Job splitting checked"  >> test_result
else
   echo "Job splitting not working properly"  >> test_result
fi

rm GenBankAcc.txt

# checking retrieval
PBS_ARRAYID=1

printf "" > all_lengths_${PBS_ARRAYID}.txt
printf "" > failed_downloads_${PBS_ARRAYID}.txt
 
for n in `cat GenBankAcc_${PBS_ARRAYID}`
do
	# Reset variables
	ERROR=0
	NEW_HEAD=null
	COUNT=null
	CHECK=null
	GENOME_LENGTH=null
	
	# CURRENTLY IN MAIN DIRECTORY
	COMMA=`echo $n | grep -c ,`
	if [ $COMMA == 0 ] #if there is only one accession...
	then
	
		#1: Retrieve FASTA file
		########################## 
		esearch -db nuccore -query "$n[ACCN]" | efetch -format fasta > $n.fasta
		COUNT=`wc -c < $n.fasta | sed 's/^ *//' | sed 's/ .*//'`
		
		ITER=1
		while [ "$COUNT" -lt 2 ] || [ "$ITER" -lt 5 ]
		do
			esearch -db nuccore -query "$n[ACCN]" | efetch -format fasta > $n.fasta
			COUNT=`wc -c < $n.fasta | sed 's/^ *//' | sed 's/ .*//'`
			ITER=$((ITER + 1))
		done
		
		if [ "$COUNT" -lt 2 ]
		then 
			printf "GenBank Accession $n failed to compile FASTA\n" >> failed_downloads_${PBS_ARRAYID}.txt
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
		esearch -db nuccore -query "$n[ACCN]" | efetch -format gp | head -50 > ${PBS_ARRAYID}.info
		
		COUNT=`wc -c < ${PBS_ARRAYID}.info | sed 's/^ *//' | sed 's/ .*//'`
		
		ITER=1
		while [ "$COUNT" -lt 2 ] || [ "$ITER" -lt 5 ]
		do
			esearch -db nuccore -query "$n[ACCN]" | efetch -format gp | head -50 > ${PBS_ARRAYID}.info
			COUNT=`wc -c < ${PBS_ARRAYID}.info | sed 's/^ *//' | sed 's/ .*//'`
			ITER=$((ITER + 1))
		done
		
		if [ "$COUNT" -lt 2 ]
		then 
			rm ${PBS_ARRAYID}.info
			printf "GenBank Accession $n failed to fetch XML file\n" >> failed_downloads_${PBS_ARRAYID}.txt
			ERROR=2
		else	
			sed '/REFERENCE/,$d' ${PBS_ARRAYID}.info | sed -e '1,/SOURCE/d' -e 's/^ *//' > ${PBS_ARRAYID}.org_messy
			if [ `grep -n ORGANISM ${PBS_ARRAYID}.org_messy | cut -c1` != "1" ]
			then
				sed '1d' ${PBS_ARRAYID}.org_messy > ${PBS_ARRAYID}.tmp
				rm ${PBS_ARRAYID}.org_messy
				mv ${PBS_ARRAYID}.tmp ${PBS_ARRAYID}.org_messy
			fi	
			head -1 ${PBS_ARRAYID}.org_messy | sed -e 's/ORGANISM//' -e 's/^ *//' > ${PBS_ARRAYID}.sm_string # species name
			sed '1d' ${PBS_ARRAYID}.org_messy | tr -d '\n' | sed -e 's/; /;/g' -e 's/\./;/' > ${PBS_ARRAYID}.tight
			cat ${PBS_ARRAYID}.sm_string >> ${PBS_ARRAYID}.tight
			tr -d '\n' < ${PBS_ARRAYID}.tight | sed 's/ /_/g' | sed "s/'//g" | sed 's/;_/:/g' > ${PBS_ARRAYID}_lineage.txt # lineage string
			
			rm ${PBS_ARRAYID}.info ${PBS_ARRAYID}.org_messy ${PBS_ARRAYID}.sm_string ${PBS_ARRAYID}.tight
		fi
		#---------------------------------------
		#Output: ${PBS_ARRAYID}_lineage.txt (file with lineage string)
		
		
		#3: Rehead FASTA file and add to all_lengths.txt
		########################## 
		if [ $ERROR == "0" ]
		then
			GENOME_LENGTH=`sed '1d' new$n.fasta | sed 's/N//' | wc -m` #determine genome length
			if [ "$GENOME_LENGTH" -lt 2 ]
			then
				printf "GenBank Accession $n failed to compile FASTA\n" >> failed_downloads_${PBS_ARRAYID}.txt
				rm -f new$n.fasta
				ERROR=1
			else	
				NEW_HEAD=`cat ${PBS_ARRAYID}_lineage.txt`
				CHECK=`echo $?`
				if [ $CHECK == "0" ]
				then					
					printf ">ACCN:$n|$NEW_HEAD\n" > $n.fasta
					sed '1d' new$n.fasta >> $n.fasta
					printf ">ACCN:$n|$NEW_HEAD\t$GENOME_LENGTH\n" >> all_lengths_${PBS_ARRAYID}.txt #add lineage string and genome length to all_lengths_${PBS_ARRAYID}.txt
					mv $n.fasta _interim #move .fasta file to _interim
					rm ${PBS_ARRAYID}_lineage.txt
					rm new$n.fasta	
				else 
					ERROR=3
					printf "GenBank Accession $n can't access ${PBS_ARRAYID}_lineage.txt\n" >> failed_downloads_${PBS_ARRAYID}.txt
					rm -f new$n.fasta
					printf "GenBank Accession $n generated errors. Associated files removed\n" >> failed_downloads_${PBS_ARRAYID}.txt
				fi
			fi
		else
			rm -f new$.fasta
			printf "GenBank Accession $n generated errors. Associated files removed\n" >> failed_downloads_${PBS_ARRAYID}.txt
		fi
		#---------------------------------------
		#Output: final .fasta and line in all_lengths_${PBS_ARRAYID}.txt
		
	else #else if there are multiple accessions...
		
		echo $n | tr ',' '\n' | sed '/^$/d' > ACC_${PBS_ARRAYID}.txt #make a list of accession numbers
		h=`head -1 ACC_${PBS_ARRAYID}.txt`
		mkdir _temp_${PBS_ARRAYID}


		#1: FOR EACH retrieve FASTA file, concatenate, get genome length
		########################## 
		for x in `cat ACC_${PBS_ARRAYID}.txt` # iterate through the list
		do
			esearch -db nuccore -query "$x[ACCN]" | efetch -format fasta > $x.fasta
			COUNT=`wc -c < $x.fasta | sed 's/^ *//' | sed 's/ .*//'`
		
			ITER=1
			while [ "$COUNT" -lt 2 ] || [ "$ITER" -lt 5 ]
			do
				esearch -db nuccore -query "$x[ACCN]" | efetch -format fasta > $x.fasta
				COUNT=`wc -c < $x.fasta | sed 's/^ *//' | sed 's/ .*//'`
				ITER=$((ITER + 1))
			done
			
			if [ "$COUNT" -lt 2 ]
			then 
				printf "GenBank Accession $x failed to fetch FASTA file (partial accession)\n" >> failed_downloads_${PBS_ARRAYID}.txt
				rm $x.fasta
			else
				awk '!/^>/ { printf "%s", $0; n = "\n" } /^>/ { print n $0; n = "" } END { printf "%s", n }' $x.fasta > tmp.$x.nolines.fasta	#create a temporary file that merges each contig into a single line
				head -1 $x.fasta > new$x.fasta	#paste header of $f.fasta into new fasta file
				sed '/^$/d' tmp.$x.nolines.fasta | grep -h -v ">" | perl -pe 's/\n/NNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNN/' >> new$x.fasta	#remove headers of each contig and concatenate the contigs with NNN spacers between them
				echo >> new$x.fasta	#add an empty line at the end of the fasta file
				rm $x.fasta
				mv new$x.fasta $x.fasta
				mv $x.fasta _temp_${PBS_ARRAYID}
				rm tmp.$x.nolines.fasta	
			fi
			
		done
		#---------------------------------------
		#Output: $x.fasta files in _temp_${PBS_ARRAYID}
		
		sleep 2
			
		# Concatenate all files in the "_temp" folder
		cd _temp_${PBS_ARRAYID}
		cat *.fasta > $h.tmp.fa
		# clean it up
		head -1 $h.tmp.fa > $h.tmp.fasta	#paste header of $h.tmp.fa into new fasta file
		grep -h -v ">" $h.tmp.fa | perl -pe 's/\n//g' >> $h.tmp.fasta	#remove headers of each contig and concatenate the contigs with NNN spacers between them
		echo >> $h.tmp.fasta	#add an empty line at the end of the fasta file
		mv $h.tmp.fasta $h.fasta
			
		mv $h.fasta .. #move .fasta file back into main directory
		cd .. #move back into main directory
		rm -rf _temp_${PBS_ARRAYID}	
		#---------------------------------------
		#Output: concatentated .fasta file (bad header)
	
		
		#2: FOR JUST THE FIRST ONE retrieve xml file and compile lineage string
		########################## 
		# Construct the taxonomy string for each species and add it to the table
		esearch -db nuccore -query "$h[ACCN]" | efetch -format gb | head -50 > ${PBS_ARRAYID}.info
		COUNT=`wc -c < ${PBS_ARRAYID}.info | sed 's/^ *//' | sed 's/ .*//'`
		
		ITER=1
		while [ "$COUNT" -lt 2 ] || [ "$ITER" -lt 5 ]
		do
			esearch -db nuccore -query "$h[ACCN]" | efetch -format gb | head -50 > ${PBS_ARRAYID}.info
			COUNT=`wc -c < ${PBS_ARRAYID}.info | sed 's/^ *//' | sed 's/ .*//'`
			ITER=$((ITER + 1))
		done
		
		if [ "$COUNT" -lt 2 ]
		then 
			rm ${PBS_ARRAYID}.info
			printf "GenBank Accession $h failed to fetch XML file\n" >> failed_downloads_${PBS_ARRAYID}.txt
			ERROR=1
		else
			sed '/REFERENCE/,$d' ${PBS_ARRAYID}.info | sed -e '1,/SOURCE/d' -e 's/^ *//' > ${PBS_ARRAYID}.org_messy
			head -1 ${PBS_ARRAYID}.org_messy | sed -e 's/ORGANISM//' -e 's/^ *//' > ${PBS_ARRAYID}.sm_string # species name
			sed '1d' ${PBS_ARRAYID}.org_messy | tr -d '\n' | sed -e 's/; /;/g' -e 's/\./;/' > ${PBS_ARRAYID}.tight
			cat ${PBS_ARRAYID}.sm_string >> ${PBS_ARRAYID}.tight
			tr -d '\n' < ${PBS_ARRAYID}.tight | sed 's/ /_/g' | sed "s/'//g" | sed 's/;_/:/g' > ${PBS_ARRAYID}_lineage.txt # lineage string
			
			rm ${PBS_ARRAYID}.info ${PBS_ARRAYID}.org_messy ${PBS_ARRAYID}.sm_string ${PBS_ARRAYID}.tight
		fi
		#---------------------------------------
		#Output: ${PBS_ARRAYID}_lineage.txt (file with lineage string)
		
		sleep 2

		#3: rehead FASTA file and add to all_lengths.txt
		########################## 	
		if [ $ERROR == "0" ]
		then	
			COUNT=`wc -c < ${PBS_ARRAYID}_lineage.txt | sed 's/^ *//' | sed 's/ .*//'`
			if [ "$COUNT" -lt 2 ]
			then 
				printf "GenBank Accession $h failed to fetch XML file\n" >> failed_downloads_${PBS_ARRAYID}.txt
				rm ${PBS_ARRAYID}_lineage.txt
			else
				NEW_HEAD=`cat ${PBS_ARRAYID}_lineage.txt`
				CHECK=`echo $?`
				if [ $CHECK == "0" ]
				then 
					printf ">ACCN:$h|$NEW_HEAD\n" > new$h.fasta
					sed '1d' $h.fasta >> new$h.fasta
					rm $h.fasta
					mv new$h.fasta $h.fasta
					GENOME_LENGTH=`sed '1d' $h.fasta | sed 's/N//' | wc -m` #determine genome length
					if [ "$GENOME_LENGTH" -lt 2 ]
					then
						printf "GenBank Accession $n failed to compile FASTA\n" >> failed_downloads_${PBS_ARRAYID}.txt
						rm $h.fasta
						ERROR=1
					else		
						printf ">ACCN:$h|$NEW_HEAD\t$GENOME_LENGTH\n" >> all_lengths_${PBS_ARRAYID}.txt #add lineage string and genome length to all_lengths_${PBS_ARRAYID}.txt
						mv $h.fasta _interim #move .fasta file to _interim
						rm ${PBS_ARRAYID}_lineage.txt
					fi
				else
					printf "GenBank Accession $h can't access ${PBS_ARRAYID}_lineage.txt\n" >> failed_downloads_${PBS_ARRAYID}.txt
					rm $h.fasta
					printf "GenBank Accession $h generated errors. Associated files removed\n" >> failed_downloads_${PBS_ARRAYID}.txt
				fi
			fi
		else
			printf "GenBank Accession $h generated errors. Associated files removed\n" >> failed_downloads_${PBS_ARRAYID}.txt
		fi
		#---------------------------------------
		#Output: final .fasta and line in all_lengths_${PBS_ARRAYID}.txt
		
		rm ACC_${PBS_ARRAYID}.txt	
	fi
done
rm GenBankAcc_${PBS_ARRAYID}

if cmp -s test/_interim _interim ; then
   echo "Genome downloading checked"  >> test_result
else
   echo "Genome downloading not working properly"  >> test_result
fi

rm all_lengths_1.txt
rm _interim
rm GenBankAcc_1
rm failed_downloads_1.txt
