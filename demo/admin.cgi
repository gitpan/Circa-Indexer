#!/usr/bin/perl -w
#
# Simple CGI interface to module Circa::Indexer
# Copyright 2000 A.Barbet alian@alianwebserver.com.  All rights reserved.
# Take a look in admin.htm
#
# $Date: 2000/09/25 23:23:24 $
# $Log: admin.cgi,v $
# Revision 1.3  2000/09/25 23:23:24  Administrateur
#
# Revision 1.2  2000/09/22 23:17:04  Administrateur
# Ajout possiblite d'indexer un site
# sans passer par un serveur Web
#
# Revision 1.1.1.1  2000/09/16 11:26:09  Administrateur
#

use strict;
use CGI qw/:standard :html3 :netscape escape unescape/;
use CGI::Carp qw/fatalsToBrowser/;

use Circa::Indexer;

my $user = "alian";	# User utilis�
my $pass = "spee/do00"; # mot de passe
my $db 	 = "circa";	# nom de la base de donn�es
my $masque = "/home/Administrateur/public_html/Circa/Indexer/demo/admin.htm";

my $indexor = new Circa::Indexer;
print header,$indexor->start_classic_html;

if (!$indexor->connect_mysql($user,$pass,$db,"localhost")) {die "Erreur � la connection MySQL:$DBI::errstr\n";}

# Drop table
if (param('drop'))
	{
	$indexor->drop_table_circa;
	print h1("Tables supprim�es");
	}

# Create table
if (param('create'))
 	{
	$indexor->create_table_circa;
	print h1("Tables cr��es");
	}

# Add site
if (param('url')) 
	{
	$indexor->addSite(param('url'),param('email'),param('titre'));
	print h1("Site ajout�");
	}

# Add local site
if (param('local_url')) 
	{
	$indexor->addLocalSite(
		param('local_url'),
		param('email'),
		param('titre'),
		param('local_file'),
		param('url_racine'),
		param('local_file_site'));
	print h1("Site ajout�");
	}

# Read url not parsed
if (param('parse_new'))
	{
	my ($nbIndexe,$nbAjoute,$nbWords,$nbWordsGood) = $indexor->parse_new_url(param('id'));
	print "$nbIndexe pages index�es, $nbAjoute pages ajout�es, $nbWordsGood mots index�s, $nbWords mots lus\n";
	}

# Update index
if (param('update')) {$indexor->update(param('nb_jours'),param('id'));}

# Liste des variables � substituer dans le template
my %vars = ('liste_site'=> $indexor->get_liste_site);
# Affichage du resultat
print $indexor->fill_template($masque,\%vars),end_html;

# Close connection
$indexor->close_connect;