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

# Make a destination folder
mkdir -p compiled_genomes

cd _interim
INC=1
touch microbe_$INC.fa

# Concatenate FASTA files into <= 2.8 GB chunks
for each in `ls *.fasta`
do
	FILE_BYTES=`wc -c < $each | sed 's/^ *//' | sed 's/ .*//'`
	MASS_BYTES=`wc -c < microbe_$INC.fa | sed 's/^ *//' | sed 's/ .*//'`
	TOT=`expr $FILE_BYTES + $MASS_BYTES`
	MAX=2800000000 #2.8e9 B = 2.8 GB; CHANGE DEFAULT MAX SIZE HERE
	if [ $TOT -lt $MAX ]
	then
		#append file to current chunk
		cat $each >> microbe_$INC.fa
	else
		#start new chunk with this file
		INC=$(( INC + 1 ))
		cat $each >> microbe_$INC.fa
	fi
	#rm $each
	gzip $each
done
mv microbe_* ../compiled_genomes

cd .. 
# Concatenate the all_lengths.txt files
cat all_lengths_* | sort | uniq > all_lengths.txt
rm all_lengths_*
mv all_lengths.txt compiled_genomes

# Concatenate the error logs
cat failed_downloads_* > failed_downloads.txt
rm failed_downloads_*

# Clean up the rest
rm mass_retrieve_V1_* mass_retrieve_V2_*

printf "\nDone! Look in compiled_genomes for the concatenated .fa files and all_lengths.txt!\n\n"
