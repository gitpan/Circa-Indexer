#!/usr/bin/perl -w
#
# Simple CGI interface to module Circa::Indexer
# Copyright 2000 A.Barbet alian@alianwebserver.com.  All rights reserved.
#
# $Log: admin_compte.cgi,v $
# Revision 1.2  2000/09/25 23:23:25  Administrateur
#
# Revision 1.1  2000/09/25 22:18:11  Administrateur
#

use diagnostics;
use strict;
use CGI qw/:standard :html3 :netscape escape unescape/;
use CGI::Carp qw/fatalsToBrowser/;

use Circa::Indexer;

my $user = "alian";	# User utilisé
my $pass = "spee/do00"; # mot de passe
my $db 	 = "circa";	# nom de la base de données
my $masque = "/home/Administrateur/public_html/Circa/Indexer/demo/admin_compte.htm";

my $indexor = new Circa::Indexer;
print header,$indexor->start_classic_html;

if (!$indexor->connect_mysql($user,$pass,$db,"localhost")) {die "Erreur à la connection MySQL:$DBI::errstr\n";}

my $compte = param('compte') || die "Vous devez fournir un identifiant:$ENV{'SCRIPT_NAME'}?compte=no_compte";

if (param('delete_url')) {$indexor->delete_url($compte,param('id'));print h1("Url supprimée");}
elsif (param('delete_categorie')) {$indexor->delete_categorie($compte,param('id'));print h1("Catégorie supprimée");}
elsif (param('rename_categorie')) {$indexor->rename_categorie($compte,param('id'),param('nom'));print h1("Catégorie renommée");}
else 
	{
	my ($responsable,$titre,$nb_page,$nb_words,$last_index,$nb_requetes,$racine) = $indexor->admin_compte($compte);
	my $refHash = $indexor->most_popular_word(10,$compte);
	my @key = keys %$refHash;
	my $buf='<table>';
	foreach (@key) {$buf.=Tr(td($_),td($$refHash{$_}));}
	$buf.='</table>';

	# Liste des variables à substituer dans le template
	my %vars = ('responsable'	=> $responsable,
    		    'titre'		=> $titre,
    		    'nbpages'		=> $nb_page,
    		    'nbmots'		=> $nb_words,
    		    'last_indexed'	=> $last_index,
    		    'mots_plus_frequent'=> $buf,
    		    'nb_requetes'	=> $nb_requetes,
    		    'liens'		=> $indexor->get_liste_liens($compte),
    		    'racine'		=> $racine,
    		    'categories'	=> $indexor->get_liste_categorie($compte),
    		    'id'		=> $compte
    		   );
	# Affichage du resultat
	print $indexor->fill_template($masque,\%vars),end_html;
	}
# Close connection
$indexor->close_connect;
