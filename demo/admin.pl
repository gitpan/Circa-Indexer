#!/usr/bin/perl -w
#
# Simple perl example to interface with module Circa::Indexer
# Copyright 2000 A.Barbet alian@alianwebserver.com.  All rights reserved.
#
# $Date: 2001/03/29 19:30:46 $
# $Log: admin.pl,v $
# Revision 1.7  2001/03/29 19:30:46  alian
# - Correction de la methode affichant les stats
# - Ajout de l'aide en ligne
#
# Revision 1.6  2001/03/25 20:09:33  alian
# - Add export and import functionnality


use diagnostics;
use strict;
use Circa::Indexer;
use Getopt::Long;

my $user = "alian";  # User utilisé
my $pass = ""; # mot de passe
my $db    = "circa2";  # nom de la base de données

my $indexor = new Circa::Indexer(
  'author'    => 'circa@alianwebserver.com', # Responsable du moteur
  'temporate'     => 0,  # Temporise les requetes sur le serveur de 8s.
  'facteur_keyword'  => 15, # <meta name="KeyWords"
  'facteur_description'  => 10, # <meta name="description"
  'facteur_titre'    => 10, # <title></title>
  'facteur_full_text'  => 1,  # reste
  'facteur_url'       => 10,
  'nb_min_mots'    => 2,  # facteur min pour garder un mot
  'niveau_max'    => 7,  # Niveau max à indexer
  'indexCgi'    => 0,  # Suit les différents liens des CGI (ex: ?nom=toto&riri=eieiei)
);
#$indexor->proxy('http://195.154.155.254:3128');
if ( (@ARGV==0) || ($ARGV[0] eq '-h'))
  {
print <<EOF;
******************************************************************
            Circa Indexer version $Circa::Indexer::VERSION

Usage: admin.pl [-h] [+create] [+drop] [+export] [+import]
  [+update=nb_day,id_site] [+most_popular=nb]
  [+parse_new=id_site] [+add=url, [email], [titre], [masque] ]
  [+add_site=url [,id] ]
  [+addLocal=file,url,email,titre,urlRacine,pathRacine]

******************************************************************
EOF

if (@ARGV>0)
  {
print <<EOF;
+create: Create table for Circa
+drop : Drop table for Circa (All Mysql data lost !)
+export : export data in circa.sql
+import : import data from circa.sql
+parse_new=id : Parse and indexe url last added for site id
+most_popular=nb,id : Get nb most popular world in database
+add_site=url [,id] : Add url in account id. If no id, 1 is used.
+update=nb_day,id : Update data for site id last indexed nb_day ago
  If page aren't updated since last index, page not fetched.

+add=url, [email], [titre], [template] : Add url to database and
create a new account.

$0 +add=http://www.alianwebserver.com/,
              alian\@alianwebserver.com,
              "Alian Web Server",
              "/home/alian/circa/circa.htm"

+addLocal=url,email,titre,file,urlRacine,pathRacine :
Add a local url to database.
Ex: $0 +addLocal=http://www.alianwebserver.com/index.html,
           alian\@alianwebserver.com,
           "Alian Web Server",
           file:///suse/index.html,
           file:///suse/,
           http://www.alianwebserver.com

If first time you use Circa, you can do:
$0 +create +add=http://www.monsite.com +update=1
for index your first url.

EOF
  }
  exit;
  }

my ($create,$drop,$update,$parse_new,$add,$addSite,$addLocal,$stats,$export,$import);
GetOptions (   "create"    => \$create,
      "drop"      => \$drop,
      "update=s"  => \$update,
      "parse_new=s" => \$parse_new,
      "add_site=s"      => \$add,
      "add=s"      => \$addSite,
      "addLocal=s"=> \$addLocal,
      "stats=s"=> \$stats,
      "export"  => \$export,
      "import"=> \$import);

if (!$indexor->connect_mysql($user,$pass,$db,"localhost")) {die "Erreur à la connection MySQL:$DBI::errstr\n";}

# Drop table
if ($drop) {$indexor->drop_table_circa;print "Tables droped\n";}
# Create table
if ($create){$indexor->create_table_circa;print "Tables created\n";}
# Add url
if ($add)
  {
  my @l=split(/,/,$add);
  if (!$l[1]) {$l[1]=1;}
  ($indexor->add_site(@l) && print $l[0]," added\n" ) || print $DBI::errstr,"\n";
  }
# Add site
if ($addSite)
  {
  my @l=split(/,/,$addSite);
  my $aa; if ($l[3]) {$aa=1;} else {$aa=0;}
  my $id = $indexor->addSite($l[0],$l[1],$l[2],$aa,undef,undef,$l[3]);
  print "Url $l[0] added and account $id created\n";
  }
if ($addLocal)
  {
  my @l=split(/,/,$addLocal);
  $indexor->addLocalSite(@l);
  print "Url $l[0] added\n";
  }
# Update index
if ($update) {$indexor->update(split(/,/,$update));print "Update done.\n";}
# Read url not parsed
if ($parse_new)
  {
  my ($nbIndexe,$nbAjoute,$nbWords,$nbWordsGood) = $indexor->parse_new_url($parse_new);
  print "$nbIndexe pages indexées, $nbAjoute pages ajoutées, $nbWordsGood mots indexés, $nbWords mots lus\n";
  }

# export data
if ($export) {$indexor->export;}

# import data
if ($import) {$indexor->import_data;}
if ($stats)
  {
  my $id=$stats;
  my ($responsable,$titre,$nb_page,$nb_words,$last_index,$nb_requetes,$racine) = $indexor->admin_compte($id);
  my $tuf = "Informations generales sur le compte $id\n\n";
  $tuf.="Responsable".'.' x (50 - length("Responsable".$responsable)).$responsable."\n";
  $tuf.="Titre du compte" .'.' x (50 - length("Titre du compte".$titre)).$titre."\n";
  $tuf.="Nombre de sites" .'.' x (50 - length("Nombre de sites".$nb_page)).$nb_page."\n";
  $tuf.="Nombre de mots".'.' x (50 - length("Nombre de mots".$nb_words)).$nb_words."\n";
  $tuf.="Derniere indexation".'.' x (50 - length("Derniere indexation".$last_index)).$last_index."\n";
  $tuf.="Racine du site".'.' x (50 - length("Racine du site".$racine)).$racine."\n\n";
  print $tuf;

  print "Les 10 mots les plus souvents trouvés:\n";
  my $refer = $indexor->most_popular_word(10);
  my @l = reverse sort { $$refer{$a} <=> $$refer{$b} } keys %$refer;
  foreach (@l)
    {
    my $sup = '.' x (25-length($_));
    my $v = $_.' '.$sup.$$refer{$_}."\n";
    print $v;
    }
  }

# Close connection
$indexor->close_connect;
