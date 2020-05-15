## VisTCR 

VisTCR is an open source software that provides an interactive visualization of high-throughput TCR sequencing data, while also incorporating a friendly graphical user interface and a flexible workflow for data analysis. The software is a client-based HTML program written in ROR (Ruby on Rails) and Data-Driven Documents Javascript (D3.js). The major features of the software include:

- Independent modules for data management and analysis.
- Freedom in grouping samples for individual analysis
- Integration of multiple cutting-edge analysis algorithms
- User-friendly interactive interface and data visualization

## Install and Run

### Install dependencies

Before running VisTCR, you will need to install

- The Ruby language (version 2.0)
- Rails (version 3.2, See the article [Installing Rails](http://railsapps.github.io/installing-rails.html) for detailed instructions and advice)
- R (R packages [Rserve](https://cran.r-project.org/web/packages/Rserve/index.html),[Biostrings](https://bioconductor.org/packages/release/bioc/html/Biostrings.html),[seqinr](https://cran.r-project.org/web/packages/seqinr/index.html),[ShortRead](https://bioconductor.org/packages/release/bioc/html/ShortRead.html),[stringdist](https://cran.r-project.org/web/packages/stringdist/index.html),[gplots](https://cran.r-project.org/web/packages/gplots/index.html),[ggplot2](https://cran.r-project.org/web/packages/ggplot2/index.html),[vegan](https://cran.r-project.org/web/packages/vegan/index.html) should be installed) 
- Java (Version 1.8 or higher)
- python (Version 2.7)
- mysql

### Getting VisTCR

You can download the code with the command

	$ git clone git://github.com/qingshanni/VisTCR.git

The source code is managed with Git. You’ll need Git on your machine (install it from http://git-scm.com/).

To use mysql database, you’ll need to modify the file **database.yml** to include your mysql password.

	development:
  		adapter: mysql2
  		database: tcr1 
  		pool: 5
  		host: localhost
  		password: *
  		encoding: utf8
  		timeout: 5000
	production:
  		adapter: mysql2
  		database: tcr1 
  		pool: 5
  		host: localhost
  		password: * 
  		encoding: utf8
  		timeout: 5000

Replace * by your mysql password.

To load required packages and codes when Rserve starts, RServe config file should be created. Create a file called Rserv.conf under /etc directory using vi or other text editor with the following contents:

	workdir ***/tools/R
	remote enable
	fileio enable
	interactive yes
	port 6311
	maxinbuf 262144
	encoding utf8
	control enable
	source init_rserve.R
	eval xx=1

Replace *** by the full path of vistcr directionary,such as /home/vistcr.

### Run VisTCR

Start Rserve

	$R CMD Rserve

**Be sure you are in the vistcr directionary,** and run the following command.

Install the required gems on your computer:

	$ bundle install

Prepare the database and add the default user to the database:

	$ rake db:create
	$ rake db:migrate
	$ rake db:seed

Start the server

	$ rails s

Open a browser window and navigate to [http://localhost:3000](http://localhost:3000). You should see the log in page. You can sign in using:

- Email: user@example.com
- Password: changeme

## Documentation

Detailed usage instructions can be found in the [user manual](https://github.com/qingshanni/VisTCR/blob/master/User_Manua.pdf)


## License

Copyright(c) <2020><QS Ni, JY Zhang, Y Wan, TMMU China, All Rights Reserved

This program is free software and can be redistributed and/or modified under the terms of the GNU General Public License as published by the Free Software Foundation; either version 2 of the license, or (at your option) any later version.

This program is distributed in the hope that it will be useful, but without any real or implied warranty of merchantability or fitness for a particular purpose. See the GNU General Public License for more details.
