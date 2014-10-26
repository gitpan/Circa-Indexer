#!/usr/bin/perl -w
#
# Simple CGI interface to module Circa::Indexer
# Copyright 2000 A.Barbet alian@alianwebserver.com.  All rights reserved.
#

use strict;
use CGI qw/:standard :html3 :netscape escape unescape/;
use CGI::Carp qw/fatalsToBrowser/;
use lib "/home/alian/circa/";
use Circa::Indexer;

my $user = "alian";  # User utilis�
my $pass = ""; # mot de passe
my $db    = "circa";  # nom de la base de donn�es
my $rep = "/home/alian/project/Circa/Indexer/demo/ecrans";

#
# $Date: 2001/03/29 22:43:39 $
# $Log: admin_compte.cgi,v $
# Revision 1.6  2001/03/29 22:43:39  alian
# - Add some thing for use interface faster (remember last screen and choice)
#
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

# Liste des masques
my $masque_categorie   = $rep."/admin_compte_categorie.htm";
my $masque_url     = $rep."/admin_compte_url.htm";
my $masque_info   = $rep."/admin_compte_infos.htm";
my $masque_stats   = $rep."/admin_compte_stats.htm";
my $masque_valide   = $rep."/admin_compte_valide.htm";
my $masque2     = $rep."/admin_url.htm";

my $masque;
my $indexor = new Circa::Indexer;
my $cgi=new CGI;
print header;

# Connection
my $compte = param('compte') || die "Vous devez fournir un identifiant:$ENV{'SCRIPT_NAME'}?compte=no_compte";
if (param('compte') eq 'acces') {$compte=param('id');}
if (!$indexor->connect_mysql($user,$pass,$db,"localhost")) {die "Erreur � la connection MySQL:$DBI::errstr\n";}
my $sommaire = $indexor->header_compte($cgi,$compte,$ENV{'SCRIPT_NAME'});

# Choix du masque
my ($responsable,$titre,$nb_page,$nb_words,$last_index,$nb_requetes,$racine);
if (param('ecran_urls')) {$masque=$masque_url;}
elsif (param('ecran_categorie')) {$masque=$masque_categorie;}
elsif (param('ecran_stats')) {$masque=$masque_stats;}
elsif (param('ecran_validation')) {$masque=$masque_valide;}
else {$masque=$masque_info; ($responsable,$titre,$nb_page,$nb_words,$last_index,$nb_requetes,$racine) = $indexor->admin_compte($compte);}

# Actions
if (param('delete_url')) {$indexor->delete_url($compte,param('id'));print h3("Url supprim�e");}
elsif (param('delete_categorie')) {$indexor->delete_categorie($compte,param('id'));print h3("Cat�gorie supprim�e");}
elsif (param('create_categorie')) {$indexor->create_categorie(param('nom'),param('id')||0,$compte);print h3("Cat�gorie ".param('nom')." ajout�e");}
elsif (param('rename_categorie')) {$indexor->rename_categorie($compte,param('id'),param('nom'));print h3("Cat�gorie renomm�e");}
elsif (param('deplace_categorie')){$indexor->deplace_categorie($compte,param('id1'),param('id2'));print h3("Cat�gorie deplac�e");}
elsif (param('personalise_categorie')){$indexor->masque_categorie($compte,param('id'),param('file'));print h3("Masque d�pos�");}
elsif (param('add_url'))
  {
  $indexor->add_site(param('url'),$compte,undef,1,undef,param('id'));
  if (!$DBI::errstr) {print h3("Site ".param('url')." ajout�");}
  else {print h3("Non ajout� : ".$DBI::errstr);}
  }
elsif (param('update_url')) {$indexor->update_site($cgi);}
elsif (param('id_valide_url')) {$indexor->valide_url(param('compte'),param('id_valide_url'));}
elsif (param('save_url'))
  {
  $indexor->updateUrl($compte,param('id'),param('url'),param('urllocal'),param('titre'),
          param('description'),param('langue'),param('categorie'),param('browse_categorie'),
          param('parse'),param('valide'),param('niveau'),param('last_check'),param('last_update'));
  print h3("Site ".param('url')." modifi�");
  }

# Ecran detaille url
if (param('ecran_url'))
  {
  my @l = $indexor->get_first("select url,local_url,titre,description,categorie,langue,parse,valide,niveau,last_check,last_update,browse_categorie
    from ".$indexor->prefix_table.$compte."links
    where id=".param('id'));

  my @list = (0,1);
  my %langue=(0=>'Non',1=>'Oui');
  my ($rl,$rt) = $indexor->get_liste_categorie($compte,$cgi);
  my %vars = ('id'  => param('id'),
        'compte'  => $compte,
        'sommaire'  => $sommaire,
        'url'  => $l[0],
        'urllocal'  => $l[1],
        'titre'  => $l[2],
            'description'=> $l[3],
            'categorie'  => $cgi->scrolling_list(-'name'=>'categorie',-'values'=>$rl,-'size'=>1,-'labels'=>$rt,-'default'=>$l[4]),
            'langue'  => $indexor->get_liste_langues($compte,$l[5],$cgi),
            'indexe'  => $cgi->scrolling_list(-'name'=>'parse',-'values'=>\@list,-'size'=>1,-'default'=>$l[6],-'labels'=>\%langue),
            'valide'  => $cgi->scrolling_list(-'name'=>'valide',-'values'=>\@list,-'size'=>1,-'default'=>$l[7],-'labels'=>\%langue),
            'niveau'  => $l[8],
            'mots'  => $indexor->get_liste_mot($compte,param('id')),
            'last_check'=> $l[9],
            'last_update'=>$l[10],
            'browse_categorie'=>$cgi->scrolling_list(-'name'=>'browse_categorie',-'values'=>\@list,-'size'=>1,-'default'=>$l[11],-'labels'=>\%langue)
           );
  # Affichage du resultat
  print $indexor->fill_template($masque2,\%vars),end_html;
  }
# Autres ecrans
else
  {
  my ($rl,$rt) = $indexor->get_liste_categorie($compte,$cgi);
  # Liste des variables � substituer par defaut dans le template
  my %vars = ('tab_valide'  => $indexor->get_liste_liens_a_valider($compte,$cgi),
            'sommaire'    => $sommaire,
            'responsable'  => $responsable,
            'titre'    => $titre,
            'nbpages'    => $nb_page,
            'nbmots'    => $nb_words,
            'last_indexed'  => $last_index,
            'racine'    => $racine,
            'categories'  => $cgi->scrolling_list(-'name'=>'id',-'values'=>$rl,-'size'=>1,-'labels'=>$rt),
            'categoriesN'  => $cgi->scrolling_list(-'name'=>'id',-'values'=>$rl,-'size'=>1,-'labels'=>$rt),
            'id'    => $compte,
            'categorie1'  => $cgi->scrolling_list(-'name'=>'id1',-'values'=>$rl,-'size'=>1,-'labels'=>$rt),
            'categorie2'  => $cgi->scrolling_list(-'name'=>'id2',-'values'=>$rl,-'size'=>1,-'labels'=>$rt),
            'id'    => $compte
           );
  # Donnees pour ecran stats
  if (param('ecran_stats'))
    {
    my $buf;
    # Mots les plus frequemment indexe
    my $refHash = $indexor->most_popular_word(10,$compte);
    my @key = keys %$refHash;
    foreach (sort {$$refHash{$b}<=>$$refHash{$a} } @key) {$buf.=Tr(td($_),td($$refHash{$_}));}
    $vars{'mots_plus_frequent'}= '<table>'.$buf.'</table>'; undef($buf);
    my ($refHash1,$refHash2) = $indexor->stat_request($compte);
    # Nombre de requetes par jour
    @key = keys %$refHash1;
    foreach (sort {$$refHash1{$b}<=>$$refHash1{$a} } @key) {$buf.=Tr(td($_),td($$refHash1{$_}));}
    $vars{'nb_request_per_day'} = '<table>'.$buf.'</table>'; undef($buf);
    # Mots les plus recherches
    @key = keys %$refHash2;
    foreach (sort {$$refHash2{$b}<=>$$refHash2{$a} } @key) {$buf.=Tr(td($_),td($$refHash2{$_}));}
    $vars{'mots_plus_recherche'} = '<table>'.$buf.'</table>';
    ($vars{'nb_requetes'}) = $indexor->get_first("select count(1) from ".$indexor->prefix_table.$compte."stats");
    }
  # Liste des url
  if (param('ecran_urls')) {$vars{'list_url'} = $vars{'liens'} = $indexor->get_liste_liens($compte,$cgi);}
  # Affichage du resultat
  print $indexor->fill_template($masque,\%vars),end_html;
  }
# Close connection
$indexor->close_connect;
