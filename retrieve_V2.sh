# Nicole Gay 
# SSP 2016
# 9 Aug 2016

# Have the user specify the input
printf "\nThis script is for the download of genomes by organism name. Download by GenBank accession (Version 1) is preferable.\n"

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
	printf "\nType the number corresponding to the input file type:\n1: NCBI .txt file\n2: List of organism names\n3: Quit\n"
	read -n 1 INPUT
	printf "\n"
	if [ $INPUT == 1 ]
	then
		LOOP1=false
		# Retrieve the organism names from the NCBI table
		ORG_COL=`tr '\t' '\n' < heads.txt | nl | grep Organism/Name | cut -f 1`
		rm heads.txt
		cut -f $ORG_COL $FILE_NAME | sed 's/ /_/g' | sed '/#Organism/d' > all_species.txt
		
		# Clean up the target species list
		cut -f 1 all_species.txt | cut -f1,2 -d'_' | sort | uniq > long_species.txt
		grep "_sp\." long_species.txt | sed 's/_.*//' > unnamed_species.txt #SAVE FOR LATER
		sed '/\./d' long_species.txt > simple_species.txt
		rm long_species.txt
		
		for a in `cat unnamed_species.txt`
		do
			grep "$a sp\." $FILE_NAME | cut -f 1 | sed 's/ /_/g' >> simple_species.txt
		done
		
	elif [ $INPUT == 2 ]
	then
		LOOP1=false
		# skip to looping through organism name
		cat $FILE_NAME > all_species.txt
		
		# Clean up the target species list
		cut -f 1 all_species.txt | cut -f1,2 -d'_' | sort | uniq > long_species.txt
		grep "_sp\." long_species.txt | sed 's/_.*//' > unnamed_species.txt #SAVE FOR LATER
		sed '/\./d' long_species.txt > simple_species.txt
		rm long_species.txt
		
		for a in `cat unnamed_species.txt`
		do
			grep "$a sp\." $FILE_NAME| cut -f 1 | sed 's/ /_/g' >> simple_species.txt
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

printf "\nNumber of species requested:\t$ASKED"
printf "\nNumber of species processed:\t$FETCHED\n"

# Set up the folders and output files
mkdir _interim
 
# Split GenBankAcc.txt into number of specified jobs
LINES=`wc -l < simple_species.txt | sed 's/^ *//' | sed 's/ .*//'`
END=`python splitJobs.py simple_species.txt $LINES $JOB_NUM` #generate JOB_NUM of chunks of GenBank accessions, each in a different file
sleep 3
printf "Number of jobs generated: $END\n\n"

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