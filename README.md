# reprDB

This package is intended for the download and compilation of whole-genome microbial databases via a cluster. Genomes of interest may be specified by GenBank accession or organism name. However, GenBank accession is preferred whenever possible. Note that scripts are provided to run this process locally, but this is NOT recommended for any large number of genomes.

## 1. Get EDirect set up

### 1.1 Install the NCBI Entrez command line tool, [EDirect](https://www.ncbi.nlm.nih.gov/books/NBK179288/) [3]

If this is your first time using `EDirect`, you need to install the command line tool. `EDirect` is compatible with UNIX and Macintosh systems. Follow the installation instructions below, copied from [here](http://www.ncbi.nlm.nih.gov/books/NBK179288/)). Note you must already have `perl` installed:

*EDirect will run on UNIX and Macintosh computers that have the Perl language installed, and under the Cygwin UNIX-emulation environment on Windows PCs. To install the EDirect software, copy the following commands and paste them into a terminal window:*

```
cd ~
/bin/bash
perl -MNet::FTP -e \
	'$ftp = new Net::FTP("ftp.ncbi.nlm.nih.gov", Passive => 1);
	$ftp->login; $ftp->binary;
	$ftp->get("/entrez/entrezdirect/edirect.tar.gz");'
gunzip -c edirect.tar.gz | tar xf -
rm edirect.tar.gz
builtin exit
export PATH=${PATH}:$HOME/edirect >& /dev/null || setenv PATH "${PATH}:$HOME/edirect"
./edirect/setup.sh
```
*This downloads several scripts into an "edirect" folder in the user's home directory. The setup.sh script then downloads any missing Perl modules, and may print an additional command for updating the PATH environment variable in the user's configuration file. Copy that command, if present, and paste it into the terminal window to complete the installation process. The editing instructions will look something like:*
```
echo "export PATH=\$PATH:\$HOME/edirect" >> $HOME/.bashrc   
```
The line `#PBS -V` at the top of the scripts called by `qsub` exports environmental variables, including those in `.bash_profile`. 

### 1.2 Request an API key from NBCI (HIGHLY RECOMMENDED)

As of May 1, 2018, you must request an API key from NCBI in order to submit multiple EDirect requests within one second. These scripts add a 5-second pause after each EDirect command to try to avoid the `429 Too Many Requests PLEASE REQUEST AN API_KEY FROM NCBI` error. However, I have still gotten this error even with the `sleep` commands to avoid it. I **highly recommend** obtaining an API key from NCBI before attempting to run these script. Follow the instructions here: https://ncbiinsights.ncbi.nlm.nih.gov/2017/11/02/new-api-keys-for-the-e-utilities/

Briefly:
1. Create an NCBI account: https://www.ncbi.nlm.nih.gov/
2. Go to your settings: https://www.ncbi.nlm.nih.gov/account/settings/
3. Click the link to create a new API key
4. Replace "YOUR_API_KEY" with your API key in the line below and run the command to add it to your `.bashrc`.
```
echo "export NCBI_API_KEY=YOUR_API_KEY" >> $HOME/.bashrc
```
5. Run `source ~/.bashrc` to export the variable (just this once)

## 2. Prepare the input file that specifies the target genomes  

Scripts are supplied for two different input types: 1) GenBank accessions; 2) organism names. GenBank accessions are preferred whenever possible. Follow the instructions below to generate input files in one of the accepted formats. 

### 2.1 Version 1: GenBank accessions (preferred)

1. PATRIC .txt file (archaea, bacteria)
    1. Go [here](https://www.patricbrc.org/) [1]
    2. BROWSE > Bacteria OR Archaea 
    3. Select "Genomes" tab
    4. Filters > Select "Representative" and "Reference"
    5. Apply any other desired filters
    6. DOWNLOAD > Text
	
2. NCBI .nbr file (viruses)
    1. Go [here](http://www.ncbi.nlm.nih.gov/genome/viruses/) [2]
    2. Download Viral Genome Data > [Accession list of all viral genomes](https://www.ncbi.nlm.nih.gov/genomes/GenomesGroup.cgi?taxid=10239&cmd=download2)
	
3. List of GenBank accessions
    * Custom by the user
    * Must have only one column, containing only GenBank accessions
    * GenBank accessions must be one per line or separated by commas (no space)
    * All genomes fetched for accession on the SAME line will be concatenated into one genome file; the script assumes all sequences belong to the organism specified by the first accession in the comma-delimited list
    * Rename the file with something simple; save it to the desired database location folder in addition to other required package files (see above)
    
### 2.2 Version 2: Organism name (suboptimal)

1. NCBI .txt file
    1. Go [here](http://www.ncbi.nlm.nih.gov/genome/browse/)
    2. Top right: Filters > Apply desired filters
    3. Middle left: Download (TSV Download)
	
2. List of organism names
    * Custom by the user
    * Must have only one column, containing only complete strings of organism names
    * Must have only one organism per line
    * Rename the file with something simple; save it to the desired database location folder in addition to other required package files (see above)

## 3. Prepare the output directory 

1. Create a new folder (e.g. `ncbi`). This path is referred to at `${outdir}`.
2. Move the file generated in Step 2 to this folder. No other files should be present in this folder. 

## 4. Run the scripts

### 4.0 Test run 

*As of 20 March 2019, please skip this step until `test` is updated*

Run `test.sh` for a quick unit test. It uses two E.coli genomes and one Cowpox virus genome to check if the outputs of the download, formatting, job split, and compilation steps are working as expected. The result of the test is output to `test_result`. Please make sure to run the test before compiling the full database to avoid overwriting.

### 4.1 Via the cluster (recommended)  

#### 4.1.1. Version 1: GenBank accessions (preferred)

1. Define a variable with the full path to the input file (generated in Step 2). Note that this file should be located in the desired output folder `${outdir}` (from Step 3).
```
infile=/users/my_sername/reprdb/taxid10239.nbr
``` 
2. Run `bash mass_retrieve_V1.sh ${infile}`
3. Enter the input file type when prompted
4. Wait for the genomes to finish downloading (this could take several hours depending on the number of genomes requested)
5. Run `bash format.sh ${infile}`
6. Find your compiled sequence files and `all_lengths.txt` file in `${outdir}/compiled_genomes`

#### 4.1.2. Version 2: Organism name (suboptimal)

1. Define a variable with the full path to the input file (generated in Step 2). Note that this file should be located in the desired output folder `${outdir}` (from Step 3).
```
infile=/users/my_sername/reprdb/names.txt
``` 
2. Run `bash mass_retrieve_V2.sh ${infile}`
3. Enter the input file type when prompted
4. Wait for the genomes to finish downloading (this could take several hours depending on the number of genomes requested)
5. Run `bash format.sh ${infile}`
6. Find your compiled sequence files and `all_lengths.txt` file in `${outdir}/compiled_genomes`

### 4.2 Locally (suboptimal)

#### 4.2.1. Version 1: GenBank accessions (preferred)

1. Start a [`screen` session](https://ss64.com/osx/screen.html), which will not kill the script if your computer goes to sleep (e.g. `screen -S reprdb`)
2. Define a variable with the full path to the input file (generated in Step 2). Note that this file should be located in the desired output folder `${outdir}` (from Step 3).
```
infile=/users/my_sername/reprdb/taxid10239.nbr
``` 
3. Run `bash local_retrieve_V1.sh ${infile}`
4. Enter the input file type when prompted
5. Detach from the screen while you wait for the script to finish running (`CTRL + A + D`)
6. Reattach to the screen to check progress (e.g. `screen -r reprdb`)
7. When the script has finished running, you may exit the screen session (type `exit` at the command line while attached to the screen)
8. Find your compiled sequence files and `all_lengths.txt` file in `${outdir}/compiled_genomes`

#### 4.2.2. Version 2: Organism name (suboptimal)

1. Start a [`screen` session](https://ss64.com/osx/screen.html), which will not kill the script if your computer goes to sleep (e.g. `screen -S reprdb`)
2. Define a variable with the full path to the input file (generated in Step 2). Note that this file should be located in the desired output folder `${outdir}` (from Step 3).
```
infile=/users/my_sername/reprdb/names.txt
``` 
3. Run `bash local_retrieve_V2.sh ${infile}`
4. Enter the input file type when prompted
5. Detach from the screen while you wait for the script to finish running (`CTRL + A + D`)
6. Reattach to the screen to check progress (e.g. `screen -r reprdb`)
7. When the script has finished running, you may exit the screen session (type `exit` at the command line while attached to the screen)
8. Find your compiled sequence files and `all_lengths.txt` file in `${outdir}/compiled_genomes`

## 5. Final outputs (found in `${outdir}/compiled_genomes`)

1. Concatenated FASTA files (`.fa`), each <= 2.8 GB (change default max size within `format.sh`)
2. An `all_lengths.txt` file with one line per genome. These lines provide the corresponding sequence name in the concatenated FASTA files and the length of the sequence, e.g.:
```
>ACCN:CP002059|Bacteria;Cyanobacteria;Nostocales;Nostocaceae;Trichormus;Nostoc_azollae_0708	5486745
```
3. A `failed_download.txt` with errors from all jobs 

## FOR UNIX NOVICES

A quick tutorial on what you need to know about UNIX in order to run this script:

* `pwd`: outputs the current path (present working directory)
* `cd /$FOLDER_NAME/$SUBFOLDER`: allows you to navigate to the indicated path (i.e. folder)
    * e.g. `cd /data/user-name`
    * e.g. `cd /..`: brings you one level up to the parent directory
* `ls`: lists everything within that directory
    * e.g. `ls`: lists all files and folders in the current directory 
    * e.g. `ls /data/s-gayn/database`: lists all files in the `database` folder
* `cat $FILE_NAME`: outputs the content of `$FILE_NAME`
* `mv $FILE $NEW_NAME`: renames `$FILE` in the current working directory to `$NEW_NAME`
* `mv $FILE $FOLDER/$NEW_LOCATION`: moves `$FILE` in the current working directory to `$FOLDER/$NEW_LOCATION`
* `cp $FILE $FOLDER/NEW_LOCATION`: copies `$FILE` in the current working directory to `$FOLDER/$NEW_LOCATION`
	
These basic commands provide everything you need to know and more in able to use this database compilation package. 
Happy compiling!

## REFERENCES

[1]	Wattam, A.R., D. Abraham, O. Dalay, T.L. Disz, T. Driscoll, J.L. Gabbard, J.J. Gillespie, R. Gough, D. Hix, R. Kenyon, D. Machi, C. Mao, E.K. Nordberg, R. Olson, R. 	Overbeek, G.D. Pusch, M. Shukla, J. Schulman, R.L. Stevens, D.E. Sullivan, V. Vonstein, A. Warren, R. Will, M.J.C. Wilson, H. Seung Yoo, C. Zhang, Y. Zhang, B.W. Sobral (2014). “PATRIC, the bacterial bioinformatics database and analysis resource.” Nucl Acids Res 42 (D1): D581-D591. doi:10.1093/nar/gkt1099. PMID: 24225323. 

[2]	NCBI viral genomes resource. Brister JR, Ako-Adjei D, Bao Y, Blinkova O.Nucleic Acids Res. 2015 Jan;43(Database issue):D571-7. doi: 10.1093/nar/gku1207. Epub 2014 Nov 	26. 

[3] 	Sayers E. E-utilities Quick Start. 2008 Dec 12 [Updated 2013 Aug 9]. In: Entrez Programming Utilities Help [Internet]. Bethesda (MD): National Center for Biotechnology Information (US); 2010-. Available from: http://www.ncbi.nlm.nih.gov/ books/NBK25500/
