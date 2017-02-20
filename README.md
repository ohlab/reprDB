This package is intended for the download and compilation of whole-genome microbial databases via the cluster.
Genomes may be specified by GenBank accession or organism name. However, GenBank accession is preferred whenever possible.

CONTENTS (required in present working directory for operation)
-----------------------------------------------------------------------------------------------------

>RUN 1 (download of individual, custom-formatted genome files)

1. retrieve_V1.sh OR retrieve_V2.sh

2. mass_retrieve_V1.qsub OR mass_retrieve_V2.qsub

3. splitJobs.py

4. Organism spec file, supplied by the user (see options below)

>RUN 2 (concatention of sequence files and clean-up of directory)

1. Outputs of RUN 1 (FASTA files, all all_lengths_*.txt files)

2. format.sh

INPUT FILE OPTIONS (and download instructions)
-----------------------------------------------------------------------------------------------------

>VERSION 1 (by GenBank accession; preferred method)
1. PATRIC .txt file (archaea, bacteria)

	Go to the following website: https://www.patricbrc.org/portal/portal/patric/Home [1]
	
	Organisms > All Bacteria OR All Archaea > Genome List
	
	Use the filters on the left to select the desired species
	
	Top middle: Download > Text File (.txt)
	
2. NCBI .nbr file (viruses)
	Go to the following website: http://www.ncbi.nlm.nih.gov/genome/viruses/ [2]
	Download Viral Genomes > Accession list of all viral genomes
3. List of GenBank accessions
	Custom by the user
	Must have only one column, containing only GenBank accessions
	GenBank accessions must be one per line or separated by commas (no space)
	All genomes fetched for accession on the SAME line will be concatenated into one genome file; the script assumes all sequences belong to the organism specified by the first accession in the comma-delimited list
Rename the file with something simple; save it to the desired database location folder in addition to other required package files (see above)

>VERSION 2 
1. NCBI .txt file
	Go to the following website: http://www.ncbi.nlm.nih.gov/genome/browse/
	Filter target list to desired scope
	Top right: Download selected records > Tab-delimited (.txt
2. List of organism names
	Custom by the user
	Must have only one column, containing only complete strings of organism names
	Must have only one organism per line
Rename the file with something simple; save it to the desired database location folder in addition to other required package files (see above)

-----------------------------------------------------------------------------------------------------
TO RUN
-----------------------------------------------------------------------------------------------------

If this is your first use, please see “NCBI Edirect” below first. Then…
1. Copy/move all required files to a unique folder with no other contents
	NOTE: It is not enough to have the package folder located in this folder; individual files must be extracted
2. Within UNIX, navigate to this unique folder (UNIX novices see below)
3. Type "sh mass_retrieve_V1.sh" (by GenBank accession) or "sh mass_retreive_V2.sh" (by organism name) at the command prompt
4. Follow the prompts output by the script
5. Wait for the genomes to finish downloading (this could take several hours depending on the number of genomes requested)
6. Make sure format.sh is in the current working directory and enter "sh format.sh" at the command prompt

-----------------------------------------------------------------------------------------------------
OUTPUTS
-----------------------------------------------------------------------------------------------------

>RUN 1
1. One FASTA file (genome nucleotide sequence file) for each organism fetched, including custom taxonomic lineage headers
	FORMAT:
		>ACCN:<GenBank accession>|Lineage_string;no_spaces;ends_with_species
		<base sequence contained on a single line with contigs and strains concatenated with a series of 200 "N"s between them>
	EXAMPLE:
		>ACCN:CP011389|Bacteria;Deinococcus-Thermus;Deinococci;Deinococcales;Deinococcaceae;Deinococcus;Deinococcus_soli_Cha_et_al._2014
		CCGGGCGCGTCGCCCTCGACGGCCAGCAGTACCGCCACCCCGGTCGGCGCGCGGCGCAGCAGGGCCTCCAGCGCCCACCCGGCCGCCGTGGTGCCCTCGCCGCCCGGCAGGCGCGGCGCGAACCC...
		>ACCN:CP002059|Bacteria;Cyanobacteria;Nostocales;Nostocaceae;Trichormus;Nostoc_azollae_0708
		TAAAGTTTTGTAAAGAAGATAAAAGAAAAGAAAATTTAATGATTTAAAAATTAAATTAGAACAGAAGAAGAAATGATTGAATCACAACAGGAGTTGTGGATAATTCTTTTGTGAAATCAAAGCTT...
2. One all_lengths_*.txt file for each job generated
	EXAMPLE:
		Accession	Genome_Length
		>ACCN:CP011389|Bacteria;Deinococcus-Thermus;Deinococci;Deinococcales;Deinococcaceae;Deinococcus;Deinococcus_soli_Cha_et_al._2014	3237084
		>ACCN:CP002059|Bacteria;Cyanobacteria;Nostocales;Nostocaceae;Trichormus;Nostoc_azollae_0708	5486745
3. One failed_downloads_*.txt error log for each job generated

>RUN 2 
1. Files (.fa) of concatenated FASTA files, each <= 2.8 GB (change default max size within format.sh)
2. Concatenated all_lengths.txt file

-----------------------------------------------------------------------------------------------------
NCBI EDirect [3]
-----------------------------------------------------------------------------------------------------

If this is your first time using this script, you will need to do some setup in regards to direct.
Essentially, you need to install edirect to your home directory and add an environmental variable to .bashrc.

1. Install edirect to your home directory by copying and pasting the following lines into the command prompt after logging into the cluster:
You may need to hit ENTER one or more times to run every line:

  cd ~
  perl -MNet::FTP -e \
    '$ftp = new Net::FTP("ftp.ncbi.nlm.nih.gov", Passive => 1); $ftp->login;
     $ftp->binary; $ftp->get("/entrez/entrezdirect/edirect.zip");'
  unzip -u -q edirect.zip
  rm edirect.zip
  export PATH=$PATH:$HOME/edirect
  ./edirect/setup.sh
  
(Taken from http://www.ncbi.nlm.nih.gov/books/NBK179288/)

2. Enter “nano ~/.bashrc” at the command prompt
3. Add the following line at the end of the document: “export PATH=$PATH:/home/$YOUR_USER_NAME/edirect”
4. Enter “Ctrl + O”, “ENTER”, “Ctrl + X” (save and exit)

Now the scripts should work, as long as the line “#PBS -V” is at the top of all sub files. This exports environmental variables. 

-----------------------------------------------------------------------------------------------------
FOR UNIX NOVICES
-----------------------------------------------------------------------------------------------------

A quick tutorial on what you need to know about UNIX in order to run this script:

pwd
	outputs the current path (present working directory)
cd /$FOLDER_NAME/$SUBFOLDER
	allows you to navigate to the indicated path (i.e. folder)
	e.g. 	cd /data/user-name
	e.g.	cd /.. (brings you one level up to the parent directory)
ls
	lists everything within that directory
	e.g. 	ls (output: all files and folders in the current directory)
	e.g.	ls /data/s-gayn/database (output: all files in the "database" folder)
cat $FILE_NAME
	outputs the content of $FILE_NAME
mv $FILE $NEW_NAME 
	renames $FILE in the current working directory to $NEW_NAME
mv $FILE $FOLDER/$NEW_LOCATION
	moves $FILE in the current working directory to the path provided ($FOLDER/$NEW_LOCATION)
cp $FILE $FOLDER/NEW_LOCATION
	copies $FILE in the current working directory to the path provided ($FOLDER/$NEW_LOCATION)
	
These basic commands provide everything you need to know and more in able to use this database compilation package. 
Happy compiling!

-----------------------------------------------------------------------------------------------------
SOURCES
-----------------------------------------------------------------------------------------------------

[1]	Wattam, A.R., D. Abraham, O. Dalay, T.L. Disz, T. Driscoll, J.L. Gabbard, J.J. Gillespie, R. Gough, D. Hix, R. Kenyon, D. Machi, C. Mao, E.K. Nordberg, R. Olson, R. 	Overbeek, G.D. Pusch, M. Shukla, J. Schulman, R.L. Stevens, D.E. Sullivan, V. Vonstein, A. Warren, R. Will, M.J.C. Wilson, H. Seung Yoo, C. Zhang, Y. Zhang, B.W. 		Sobral (2014). “PATRIC, the bacterial bioinformatics database and analysis resource.” Nucl Acids Res 42 (D1): D581-D591. doi:10.1093/nar/gkt1099. PMID: 24225323. 
[2]	NCBI viral genomes resource. Brister JR, Ako-Adjei D, Bao Y, Blinkova O.Nucleic Acids Res. 2015 Jan;43(Database issue):D571-7. doi: 10.1093/nar/gku1207. Epub 2014 Nov 	26. 
[3] 	Sayers E. E-utilities Quick Start. 2008 Dec 12 [Updated 2013 Aug 9]. In: Entrez Programming Utilities Help [Internet]. Bethesda (MD): National Center for 	Biotechnology Information (US); 2010-. Available from: http://www.ncbi.nlm.nih.gov/ books/NBK25500/
