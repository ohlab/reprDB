#PBS -N format_db
#PBS -l walltime=60:00:00,mem=8gb,nodes=1:ppn=16

printf "\nThis script concatenates all FASTA files in _interim (a sub-folder in the pwd) into larger chunks and cleans up other outputs of retrieve.sh. Individual FASTA files are compressed once concatenated. You may delete them upon completion of this script.\n\n"

printf "Would you like to continue? (Y/N): "
LOOP=true
while $LOOP
do
	read -n 1 ANS
	printf "\n\n"
	if [ $ANS == "y" ] || [ $ANS == "Y" ]
	then
		LOOP=false
	elif [ $ANS == "n" ] || [ $ANS == "N" ]
	then
		printf "\n\nTerminating program...\n\n"
		exit
	else
		printf "\n\nInvalid entry. Type Y or N: "
	fi
done 

# Make a destination folder
VAL=`ls | grep -c _bowtie_req` # make the _bowtie_req folder if it doesn't already exist
if [ $VAL != "1" ]
then
	mkdir _bowtie_req
fi

cd _interim
INC=1
printf "" > microbe_$INC.fa

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
mv microbe_* ../_bowtie_req

cd .. 
# Concatenate the all_lengths.txt files
cat all_lengths_* | sort | uniq > all_lengths.txt
rm all_lengths_*
mv all_lengths.txt _bowtie_req

# Concatenate the error logs
cat failed_downloads_* > failed_downloads.txt
rm failed_downloads_*

# Clean up the rest
rm -f mass_retrieve_V1_* mass_retrieve_V2_*

VAL=`ls | grep -c _package` # make a _package folder if it doesn't already exist
if [ $VAL != "1" ]
then
	mkdir _package
fi

printf "Ignore any following errors regarding \"mv\"..."
mv -t _package splitJobs.py mass_retrieve_V{1..2}.qsub retrieve_V{1..2}.sh failed_downloads.txt

printf "\nDone! Look in _bowtie_req for the concatenated .fa files and all_lengths.txt!\n\n"