#!/usr/bin/perl -w
#
# Simple CGI interface to module Circa::Indexer
# Copyright 2000 A.Barbet alian@alianwebserver.com.  All rights reserved.
#
# $Log: admin_compte.cgi,v $
# Revision 1.5  2000/11/23 22:18:48  Administrateur
# Add "valide url" feature
#
# Revision 1.4  2000/10/28 20:35:18  Administrateur
# Nouvelle interface d'administration
#
# Revision 1.3  2000/10/21 15:48:51  Administrateur
# Ajout de la possibilite d'inscrire une url par l'administration par compte
#
# Revision 1.2  2000/09/25 23:23:25  Administrateur
#
# Revision 1.1  2000/09/25 22:18:11  Administrateur
#

use strict;
use CGI qw/:standard :html3 :netscape escape unescape/;
use CGI::Carp qw/fatalsToBrowser/;

use Circa::Indexer;

my $user = "alian";	# User utilisé
my $pass = ""; # mot de passe
my $db 	 = "circa";	# nom de la base de données
my $rep = "/home/Administrateur/public_html/Circa/Indexer/demo/ecrans";
my $masque_categorie 	= $rep."/admin_compte_categorie.htm";
my $masque_url 		= $rep."/admin_compte_url.htm";
my $masque_info 	= $rep."/admin_compte_infos.htm";
my $masque_stats 	= $rep."/admin_compte_stats.htm";
my $masque_valide 	= $rep."/admin_compte_valide.htm";
my $masque2 		= $rep."/admin_url.htm";
my $masque;

my $indexor = new Circa::Indexer;
my $cgi=new CGI;
print header;

if (param('ecran_urls')) {$masque=$masque_url;}
elsif (param('ecran_categorie')) {$masque=$masque_categorie;}
elsif (param('ecran_stats')) {$masque=$masque_stats;}
elsif (param('ecran_validation')) {$masque=$masque_valide;} 
else {$masque=$masque_info;}
if (!$indexor->connect_mysql($user,$pass,$db,"localhost")) {die "Erreur à la connection MySQL:$DBI::errstr\n";}

my $compte = param('compte') || die "Vous devez fournir un identifiant:$ENV{'SCRIPT_NAME'}?compte=no_compte";
my $sommaire = $indexor->header_compte($cgi,$compte,$ENV{'SCRIPT_NAME'});

if (param('delete_url')) {$indexor->delete_url($compte,param('id'));print h1("Url supprimée");}
elsif (param('delete_categorie')) {$indexor->delete_categorie($compte,param('id'));print h1("Catégorie supprimée");}
elsif (param('create_categorie')) {$indexor->create_categorie(param('nom'),param('id')||0,$compte);print h1("Catégorie ajoutée");}
elsif (param('rename_categorie')) {$indexor->rename_categorie($compte,param('id'),param('nom'));print h1("Catégorie renommée");}
elsif (param('deplace_categorie')){$indexor->deplace_categorie($compte,param('id1'),param('id2'));print h1("Catégorie deplacée");}
elsif (param('add_url')) {$indexor->add_site(param('url'),$compte,undef,1,undef,param('id'));print h1("Site ajouté");}
elsif (param('update_url')) {$indexor->update_site($cgi);}
elsif (param('id_valide_url')) {$indexor->valide_url(param('compte'),param('id_valide_url'));}
elsif (param('save_url')) 
	{
	$indexor->updateUrl($compte,param('id'),param('url'),param('urllocal'),param('titre'),
			    param('description'),param('langue'),param('categorie'),param('browse_categorie'),
			    param('parse'),param('valide'),param('niveau'),param('last_check'),param('last_update'));
	print h1("Site modifié");
	}

if (param('ecran_url'))
	{
	my @l = $indexor->get_first("select url,local_url,titre,description,categorie,langue,parse,valide,niveau,last_check,last_update,browse_categorie
		from ".$indexor->prefix_table.$compte."links 
		where id=".param('id'));

	my @list = (0,1);
	my %langue=(0=>'Non',1=>'Oui');	
	my %vars = ('id'	=> param('id'),
		    'compte'	=> $compte,
		    'sommaire'	=> $sommaire,
		    'url'	=> $l[0],
		    'urllocal'	=> $l[1],
		    'titre'	=> $l[2],
    		    'description'=> $l[3],
    		    'categorie'	=> $indexor->get_liste_categorie($compte,$cgi,'yes','categorie',$l[4]),
    		    'langue'	=> $indexor->get_liste_langues($compte,$l[5],$cgi),
    		    'indexe'	=> $cgi->scrolling_list(-'name'=>'parse',-'values'=>\@list,-'size'=>1,-'default'=>$l[6],-'labels'=>\%langue),
    		    'valide'	=> $cgi->scrolling_list(-'name'=>'valide',-'values'=>\@list,-'size'=>1,-'default'=>$l[7],-'labels'=>\%langue),
    		    'niveau'	=> $l[8],
    		    'mots'	=> $indexor->get_liste_mot($compte,param('id')),
    		    'last_check'=> $l[9],
    		    'last_update'=>$l[10],
    		    'browse_categorie'=>$cgi->scrolling_list(-'name'=>'browse_categorie',-'values'=>\@list,-'size'=>1,-'default'=>$l[11],-'labels'=>\%langue)
    		   );
	# Affichage du resultat
	print $indexor->fill_template($masque2,\%vars),end_html;	
	}
else 
	{
	my ($responsable,$titre,$nb_page,$nb_words,$last_index,$nb_requetes,$racine) = $indexor->admin_compte($compte);
	my $refHash = $indexor->most_popular_word(10,$compte);
	my @key = keys %$refHash;
	my $buf='<table>';
	foreach (@key) {$buf.=Tr(td($_),td($$refHash{$_}));}
	$buf.='</table>';
	my $liens = $indexor->get_liste_liens($compte,$cgi);
	# Liste des variables à substituer dans le template
	my %vars = ('tab_valide'	=> $indexor->get_liste_liens_a_valider($compte,$cgi),
		    'sommaire'		=> $sommaire,
		    'responsable'	=> $responsable,
    		    'titre'		=> $titre,
    		    'nbpages'		=> $nb_page,
    		    'nbmots'		=> $nb_words,
    		    'last_indexed'	=> $last_index,
    		    'mots_plus_frequent'=> $buf,
    		    'nb_requetes'	=> $nb_requetes,
    		    'liens'		=> $liens,
    		    'racine'		=> $racine,
    		    'categories'	=> $indexor->get_liste_categorie($compte,$cgi),
    		    'categoriesN'	=> $indexor->get_liste_categorie($compte,$cgi,'yes'),
    		    'id'		=> $compte,
    		    'categorie1'	=> $indexor->get_liste_categorie($compte,$cgi,'yes','id1'),
    		    'categorie2'	=> $indexor->get_liste_categorie($compte,$cgi,'yes','id2'),
    		    'list_url'		=> $liens,
    		    'id'		=> $compte
    		   );
	# Affichage du resultat
	print $indexor->fill_template($masque,\%vars),end_html;
	}
# Close connection
$indexor->close_connect;
