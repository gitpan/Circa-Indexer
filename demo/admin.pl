#!/usr/bin/perl -w
#
# Simple perl example to interface with module Circa::Indexer
# Copyright 2000 A.Barbet alian@alianwebserver.com.  All rights reserved.
#
# $Date: 2000/09/25 23:23:24 $
# $Log: admin.pl,v $
# Revision 1.3  2000/09/25 23:23:24  Administrateur
# *** empty log message ***
#
# Revision 1.2  2000/09/20 17:50:50  Administrateur
# Add possibilities to index local file without
# use a web server.
#
# Revision 1.1.1.1  2000/09/09 17:08:58  Administrateur
# Release initiale
#

#use diagnostics;
use strict;
use Circa::Indexer;
use Getopt::Long;

my $user = "alian";	# User utilisé
my $pass = "spee/do00"; # mot de passe
my $db 	 = "circa";	# nom de la base de données
my $indexor = new Circa::Indexer;

if (@ARGV==0) 
	{
print <<EOF;

            SCRIPT FOR CIRCA ADMINISTRATOR

Usage: admin.pl [+create] [+drop] [+update=nb_day,id_site] [+most_popular=nb] 
		[+parse_new=id_site] [+add=url,email,titre]
                [+addLocal=file,url,email,titre,urlRacine,pathRacine]

+create             : Create table for Circa in MySQL database
+drop               : Drop table for Circa in MySQL database (All data lost !)
+update=nb_day,id   : Update data for site id last indexed nb_day ago.
                      If page aren't updated since last index, page not fetched.
                      For update all page, +update=a
+parse_new=id       : Parse and indexe url last added for site id
+most_popular=nb,id : Get nb most popular world in database

+add=url,email,titre : Add url to database. Parse and indexed it.
Ex: admin.pl +add=http://www.alianwebserver.com/, 
                  alian\@alianwebserver.com, 
                  "Alian Web Server"

+addLocal=url,email,titre,file,urlRacine,pathRacine : 
Add a local url to database. Parse and indexed it.
Ex: admin.pl +addLocal=http://www.alianwebserver.com/index.html, 
		       alian\@alianwebserver.com, 
		       "Alian Web Server", 
		       file:///suse/index.html, 
		       file:///suse/, 
		       http://www.alianwebserver.com
EOF

	exit;
	}	  	

my ($create,$drop,$update,$parse_new,$add,$addLocal,$most_popular);
GetOptions ( 	"create"    => \$create,
	  	"drop"	    => \$drop,
	  	"update=s"  => \$update,
	  	"parse_new=s" => \$parse_new,
	  	"add=s"	    => \$add,
	  	"addLocal=s"=> \$addLocal,
	  	"most_popular=s"=> \$most_popular);
  	
if (!$indexor->connect_mysql($user,$pass,$db,"localhost")) {die "Erreur à la connection MySQL:$DBI::errstr\n";}

# Drop table
if ($drop) {$indexor->drop_table_circa;print "Tables droped\n";}
# Create table
if ($create){$indexor->create_table_circa;print "Tables created\n";}
# Update index
if ($update) {$indexor->update(split(/,/,$update));}
# Add site
if ($add) 
	{
	my @l=split(/,/,$add);
	$indexor->addSite(@l);
	print "Url $l[0] added\n";
	}
if ($addLocal) 
	{
	my @l=split(/,/,$addLocal);
	$indexor->addLocalSite(@l);
	print "Url $l[0] added\n";
	}

if ($most_popular) 
	{
	my $refer = $indexor->most_popular_word($most_popular);
	my @l = reverse sort { $$refer{$a} <=> $$refer{$b} } keys %$refer;
	foreach (@l) {print $_,':',$$refer{$_},"\n";}	
	}
# Read url not parsed
if ($parse_new)
	{
	my ($nbIndexe,$nbAjoute,$nbWords,$nbWordsGood) = $indexor->parse_new_url($parse_new);
	print "$nbIndexe pages indexées, $nbAjoute pages ajoutées, $nbWordsGood mots indexés, $nbWords mots lus\n";
	}
# Close connection
$indexor->close_connect;
