package Circa::Indexer;

# module Circa::Indexer : provide function to administrate Circa
# Copyright 2000 A.Barbet alian@alianwebserver.com.  All rights reserved.

# $Log: Indexer.pm,v $
# Revision 1.11  2001/03/29 19:36:32  alian
# - Add pod documentation for add_site function
# - Add some default parameters
# - Optimize update routine
# - Change export and import routine for allow no password
# - Add return for addSite function (id of account created)
#
# Revision 1.10  2001/03/25 19:43:24  alian
# - Update POD documentation
# - Add export and import_data routine
# - Add stats routines
#
# Revision 1.9  2001/02/05 00:09:32  alian
# - Add parameters to new method
# - Correct set_host_indexed method
# - Add pod documentation
#
# Revision 1.8  2000/11/23 22:11:11  Administrateur
# - Add template as parameter
# - Add timeout to 25s.
# - Add updateUrl function
# - Add "valide url" feature
# - Add auto-categorie creation as option
# - Add level control feature for estimate size index
#   and limit use of speeder feature
# - Replace count(*) with count(1)
# - Add some function for administrate each compte
# - Add feature to use categories a you want
# - Add some pod documentation
# - Correct some bugs
# - TODO: find a bug with LinkExtor on some site like
#         www.looksmart.bug It's give out of memory
#   error :-( the todo is correct this problem
#
# Revision 1.7  2000/10/21 15:40:10  Administrateur
# - Remove use of modules HTML::Parse, CGI, diagnostics
# - Correct lot of things to get down memory usage
#
# Revision 1.6  2000/10/18 11:30:00  Administrateur
# -Add english doc Indexer/Indexer.pm
# -Correct problem with local indexing
#
# Revision 1.5  2000/09/28 16:05:14  Administrateur
# - Update method in parsing for reject too frequent word
# - Correct definition of table stats
#
# Revision 1.4  2000/09/25 23:25:43  Administrateur
# - Update possibilities to index several site on a same database
# - Update navigation by category
# - Add a landa client to administrate one site (admin_compte.cgi)
# - Use new MCD
#

use strict;
use LWP::RobotUA;
use HTML::LinkExtor;
use HTML::Entities;
use DBI;
use vars qw(@ISA @EXPORT @EXPORT_OK %EXPORT_TAGS $VERSION);
require Exporter;

@ISA = qw(Exporter);
@EXPORT = qw();
$VERSION = ('$Revision: 1.11 $ ' =~ /(\d+\.\d+)/)[0];

########## CONFIG  ##########
my %ConfigMoteurDefault=(
  'author'    => 'circa@alianwebserver.com', # Responsable du moteur
  'temporate'     => 1,  # Temporise les requetes sur le serveur de 8s.
  'facteur_keyword'  => 15, # <meta name="KeyWords"
  'facteur_description'  => 10, # <meta name="description"
  'facteur_titre'    => 10, # <title></title>
  'facteur_full_text'  => 1,  # reste
  'facteur_url' => 15, # Mots trouvés dans l'url
  'nb_min_mots'    => 2,  # facteur min pour garder un mot
  'niveau_max'    => 7,  # Niveau max à indexer
  'indexCgi'    => 0,  # Suit les différents liens des CGI (ex: ?nom=toto&riri=eieiei)
  );
# Mots a ne pas indexer
my %bad = map {$_ => 1} qw (
  le la les et des de and or the un une ou qui que quoi a an
  &quot je tu il elle nous vous ils elles eux ce cette ces cet celui celle ceux
  celles qui que quoi dont ou mais ou et donc or ni car parceque un une des pour
  votre notre avec sur par sont pas mon ma mes tes ses the from for and our my
  his her and your to in that else also with this you date not has net but can
  see who dans est \$ { & com/ + son tous plus/); # Mot à ne pas indexer
########## FIN CONFIG  ##########

=head1 NAME

Circa::Indexer - provide functions to administrate Circa,
a www search engine running with Mysql

=head1 SYNOPSIS

 use Circa::Indexer;
 my $indexor = new Circa::Indexer;

 if (!$indexor->connect_mysql($user,$pass,$db))
  {die "Erreur à la connection MySQL:$DBI::errstr\n";}

 $indexor->create_table_circa;

 $indexor->drop_table_circa;

 $indexor->addSite("http://www.alianwebserver.com/",
                   'alian@alianwebserver.com',
                   "Alian Web Server");

 my ($nbIndexe,$nbAjoute,$nbWords,$nbWordsGood) = $indexor->parse_new_url(1);
 print   "$nbIndexe pages indexées,"
   "$nbAjoute pages ajoutées,"
   "$nbWordsGood mots indexés,"
   "$nbWords mots lus\n";

 $indexor->update(30,1);

Look in admin.pl,admin.cgi,admin_compte.cgi

=head1 DESCRIPTION

This is Circa::Indexer, a module who provide functions
to administrate Circa, a www search engine running with
Mysql. Circa is for your Web site, or for a list of sites.
It indexes like Altavista does. It can read, add and
parse all url's found in a page. It add url and word
to MySQL for use it at search.

This module provide routine to :

=over

=item *

Add url

=item *

Create and update each account

=item *

Parse url, Index words, and so on.

=item *

Provide routine to administrate present url

=back

Remarques:

=over

=item *

This file are not added : doc,zip,ps,gif,jpg,gz,pdf,eps,png,
deb,xls,ppt,class,GIF,css,js,wav,mid

=item *

Weight for each word is in hash $ConfigMoteur

=back

=head2 Features ?

Features

=over

=item *

Search Features

=over

=item *

Boolean query language support : or (default) and ("+") not ("-"). Ex perl + faq -cgi :
Documents with faq, eventually perl and not cgi.

=item *

Client Perl or PHP

=item *

Can browse site by directory / rubrique.

=item *

Search for different criteria: news, last modified date, language, URL / site.

=back

=item *

Full text indexing

=item *

Different weights for title, keywords, description and rest of page HTML read can be given in configuration

=item *

Herite from features of LWP suite:

=over

=item *

Support protocol HTTP://,FTP://, FILE:// (Can do indexation of filesystem without talk to Web Server)

=item *

Full support of standard robots exclusion (robots.txt). Identification with
CircaIndexer/0.1, mail alian@alianwebserver.com. Delay requests to
the same server for 8 secondes. "It's not a bug, it's a feature!" Basic
rule for HTTP serveur load.

=item *

Support proxy HTTP.

=back

=item *

Make index in MySQL

=item *

Read HTML and full text plain

=item *

Several kinds of indexing : full, incremental, only on a particular server.

=item *

Documents not updated are not reindexed.

=item *

All requests for a file are made first with a head http request, for information
such as validate, last update, size, etc.Size of documents read can be
restricted (Ex: don't get all documents > 5 MB). For use with low-bandwidth
connections, or computers which do not have much memory.

=item *

HTML template can be easily customized for your needs.

=item *

Admin functions available by browser interface or command-line.

=item *

Index the different links found in a CGI (all after name_of_file?)

=back

=head2 How it's work ?

Circa parse html document. convert it to text. It count all
word found and put result in hash key. In addition of that,
it read title, keywords, description and add a weight to
all word found.

Example:
 my %ConfigMoteur=(
  'author'    => 'circa@alianwebserver.com', # Responsable du moteur
  'temporate'     => 1,  # Temporise les requetes sur le serveur de 8s.
  'facteur_keyword'  => 15, # <meta name="KeyWords"
  'facteur_description'  => 10, # <meta name="description"
  'facteur_titre'    => 10, # <title></title>
  'facteur_full_text'  => 1,  # reste
  'facteur_url' => 15, # Mots trouvés dans l'url
  'nb_min_mots'    => 2,  # facteur min pour garder un mot
  'niveau_max'    => 7,  # Niveau max à indexer
  'indexCgi'    => 0,  # Suit les différents liens des CGI (ex: ?nom=toto&riri=eieiei)
  );

 <html>
 <head>
 <meta name="KeyWords"
 CONTENT="informatique,computing,javascript,CGI,perl">
 <meta name="Description" CONTENT="Rubriques Informatique (Internet,Java,Javascript, CGI, Perl)">
 <title>Alian Web Server:Informatique,Société,Loisirs,Voyages,Expression</title>
 </head>
 <body>
 different word: cgi, perl, cgi
 </body>
 </html>

After parsing I've a hash with that:

 $words{'informatique'}= 15 + 10 + 10 =35
 $words{'cgi'} = 15 + 10 +1
 $words{'different'} = 1

Words is add to database if total found is > $ConfigMoteur{'nb_min_mots'}
(2 by default). But if you set to 1, database will grow very quicly but
allow you to perform very exact search with many worlds so you can do phrase
searches. But if you do that, think to take a look at size of table
relation.

After page is read, it's look into html link. And so on. At each time, the level
grow to one. So if < to $Config{'niveau_max'}, url is added.

=head1 Remarques

Use phpMyAdmin, and script dump and import.cgi for make index on another server

=head1 VERSION

$Revision: 1.11 $

=head1 Class Interface

=head2 Constructors and Instance Methods

=over

=item new    [PARAMHASH]

You can use the following keys in PARAMHASH:

=over

=item author

Default: 'circa@alianwebserver.com', appear in log file of web server indexed (as agent)

=item  temporate

Default: 1,  boolean. If true, wait 8s between request on same server and
LWP::RobotUA will be used. Else this is LWP::UserAgent (more quick because it
doesn't request and parse robots.txt rules, but less clean because a robot must always
say who he is, and heavy server load is avoid).

=item facteur_keyword

Default: 15, weight of word found on meta KeyWords

=item facteur_description

Default:10, weight of word found on meta description"

=item facteur_titre

Default:10, weight of word found on  <title></title>

=item facteur_full_text

Default:1,  weight of word found on rest of page

=item facteur_url

Default: 15, weight of word found in url

=item nb_min_mots

Default: 2, minimal number of times a word must be found to be added

=item niveau_max

Default: 7, Maximal number of level of links to follow

=item indexCgi

Default 0, follow of not links of CGI (ex: ?nom=toto&riri=eieiei)

=back

=cut

sub new {
        my $class = shift;
        my $self = {};
        bless $self, $class;
        $self->{SERVER_PORT}  ="3306";   # Port de mysql par default
        $self->{SIZE_MAX}     = 1000000;  # Size max of file read
        $self->{PREFIX_TABLE} = 'circa_';
        $self->{HOST_INDEXED} = undef;
        $self->{DBH} = undef;
        $self->{PROXY} = undef;
        $self->{ConfigMoteur} = \%ConfigMoteurDefault;
        if (@_)
          {
          my %vars =@_;
          while (my($n,$v)= each (%vars)) {$self->{'ConfigMoteur'}->{$n}=$v;}
          }
        return $self;
        }

=item size_max($size)

Get or set size max of file read by indexer (For avoid memory pb).

=cut

sub size_max
  {
  my $self = shift;
  if (@_) {$self->{SIZE_MAX}=shift;}
  return $self->{SIZE_MAX};
  }

=item port_mysql($port)

Get or set the MySQL port

=cut

sub port_mysql
  {
  my $self = shift;
  if (@_) {$self->{SERVER_PORT}=shift;}
  return $self->{SERVER_PORT};
  }

=item host_indexed($host)

Get or set the host indexed.

=cut

sub host_indexed
  {
  my $self = shift;
  if (@_) {$self->{HOST_INDEXED}=shift;}
  return $self->{HOST_INDEXED};
  }

=item set_host_indexed($url)

Set base directory with $url. It's used for restrict access
only to files found on sub-directory on this serveur.

=cut

sub set_host_indexed
  {
  my $this=shift;
  my $url=$_[0];
  if ($url=~/^(http:\/\/.*?)\/$/) {$this->host_indexed($1);}
  elsif ($url=~/^(http:\/\/.*?)\/[^\/]+$/) {$this->host_indexed($1);}
  elsif ($url=~/^(file:\/\/\/[^\/]*)\//) {$this->host_indexed($1);}
  else {$this->host_indexed($url);}
  }

=item proxy($adr_proxy)

Get or set proxy for LWP::Robot or LWP::Agent

Ex: $circa->proxy('http://proxy.sn.no:8001/');

=cut

sub proxy
  {
  my $self = shift;
  if (@_) {$self->{PROXY}=shift;}
  return $self->{PROXY};
  }

=item prefix_table

Get or set the prefix for table name for use Circa with more than one
time on a same database

=cut

sub prefix_table
  {
  my $self = shift;
  if (@_) {$self->{PREFIX_TABLE}=shift;}
  return $self->{PREFIX_TABLE};
  }

=item connect_mysql($user,$password,$db,$server)

=over

=item *

$user     : User MySQL

=item *

$password : Password MySQL

=item *

$db       : Database MySQL

=item *

$server   : Adr IP MySQL

=back

Connect Circa to MySQL. Return 1 on succes, 0 else

=cut

sub connect_mysql
  {
  my ($this,$user,$password,$db,$server)=@_;
  my $driver = "DBI:mysql:database=$db;host=$server;port=".$this->port_mysql;
  $this->{_USER} = $user;
  $this->{_PASSWORD} = $password;
  $this->{_DB} = $db;
  $this->{DBH} = DBI->connect($driver,$user,$password,{ PrintError => 0 }) || return 0;
  return 1;
  }

=item close_connect

Close connection to MySQL

=back

=cut

sub close_connect {$_[0]->{DBH}->disconnect;}

=head2 Methods use for global adminstration

=over

=item addSite($url,$email,$titre,$categorieAuto,$cgi,$rep,$file);

Ajoute le site d'url $url, responsable d'adresse mail $email à la bd de Circa
Retourne l'id du compte cree

Create account for url $url. Return id of account created.

=cut

sub addSite
  {
  my ($self,$url,$email,$titre,$categorieAuto,$cgi,$rep,$file)=@_;
  #print "$url,$email,$titre,$categorieAuto,$cgi,$rep,$file\n";
  if ($cgi)
    {
    $file=$cgi->param('file');
    my $tmpfile=$cgi->tmpFileName($file); # chemin du fichier temp
    if ($file=~/.*\\(.*)$/) {$file=$1;}
    my $fileC=$file;
    $file = $rep.$file;
    use File::Copy;
    copy($tmpfile,$file) || die "Impossible de creer $file avec $tmpfile:$!\n<br>";
    }
  if (!$email) {$email='Inconnu';}
  if (!$titre) {$titre='Non fourni';}
  if (!$file) {$file=' ';}
  if (!$categorieAuto) {$categorieAuto=0;}
  my $sth = $self->{DBH}->prepare("insert into ".$self->prefix_table."responsable(email,titre,categorieAuto,masque) values('$email','$titre',$categorieAuto,'$file')");
  $sth->execute || print "Erreur: $DBI::errstr<br>\n";
  $sth->finish;
  $self->create_table_circa_id($sth->{'mysql_insertid'});
  $self->add_site($url,$sth->{'mysql_insertid'},undef,1);
  return $sth->{'mysql_insertid'};
  }

=item addLocalSite($url,$email,$titre,$local_url,$path,$urlRacine,$categorieAuto,$cgi,$rep,$file);

Add a local $url

=cut

sub addLocalSite
  {
  my ($self,$url,$email,$titre,$local_url,$path,$urlRacine,$categorieAuto,$cgi,$rep,$file)=@_;
  if ($cgi)
    {
    $file=$cgi->param('file');
    my $tmpfile=$cgi->tmpFileName($file); # chemin du fichier temp
    if ($file=~/.*\\(.*)$/) {$file=$1;}
    my $fileC=$file;
    $file = $rep.$file;
    use File::Copy;
    copy($tmpfile,$file) || die "Impossible de creer $file avec $tmpfile:$!\n<br>";
    }
  my $sth = $self->{DBH}->prepare("insert into ".$self->prefix_table."responsable(email,titre,categorieAuto) values('$email','$titre',$categorieAuto)");
  $sth->execute;
  $sth->finish;
  my $id = $sth->{'mysql_insertid'};
  $self->{DBH}->do("insert into ".$self->prefix_table."local_url values($id,'$urlRacine','$path');");
  $self->create_table_circa_id($sth->{'mysql_insertid'});
  $self->add_site($url,$id,$local_url,1) || print "Erreur: $DBI::errstr<br>\n";
  }

=item updateUrl($compte,$id,$url,$urllocal,$titre,$description,$langue,
     $categorie,$browse_categorie,$parse,$valide,$niveau,$last_check,$last_update)

Update url $id on table $prefix.$compte.links

=cut

sub updateUrl
  {
  my ($self,$compte,$id,$url,$urllocal,$titre,$description,$langue,$categorie,$browse_categorie,$parse,$valide,$niveau,$last_check,$last_update)=@_;
  $titre=~s/'/\\'/g;
  $description=~s/'/\\'/g;
  my $requete ="update ".$self->prefix_table.$compte."links set
    url='$url',
    local_url='$urllocal',
    titre='$titre',
    description='$description',
    langue='$langue',
    categorie=$categorie,
    browse_categorie='$browse_categorie',
    parse='$parse',
    valide=$valide,
    niveau=$niveau,
    last_check='$last_check',
    last_update='$last_update'
  where id=$id";#print $requete;
  $self->{DBH}->do($requete) || print "Erreur: $requete $DBI::errstr<br>\n";
  }


=item parse_new_url($idp)

Parse les pages qui viennent d'être ajoutée. Le programme va analyser toutes
les pages dont la colonne 'parse' est égale à 0.

Retourne le nombre de pages analysées, le nombre de page ajoutées, le
nombre de mots indexés.

=cut

sub parse_new_url
  {
  my $self=shift;
  #system('/bin/ps m|grep perl>>/tmp/ressource');
  my $idp=$_[0];
  my ($nb,$nbAjout,$nbWords,$nbWordsGood)=(0,0,0,0);
  my $requete="select id,url,niveau,categorie from ".$self->prefix_table.$idp."links where parse='0' and valide=1 and local_url is null order by id";
  my $sth = $self->{DBH}->prepare($requete);
  $self->set_agent;
  if ($sth->execute())
    {
    my ($categorieAuto)=$self->get_first("select categorieAuto from ".$self->prefix_table."responsable where id=$idp");
    while (my ($id,$url,$niveau,$categorie)=$sth->fetchrow_array)
      {
      my ($res,$nbw,$nbwg) = $self->look_at($url,$id,$idp,undef,undef,$categorieAuto,$niveau,$categorie);
      if ($res==-1) {$self->{DBH}->do("update ".$self->prefix_table.$idp."links set valide='0' where id=$id");}
      else {$nbAjout+=$res;$nbWords+=$nbw;$nb++;$nbWordsGood+=$nbwg;}
      }
    }
  else {print "\nYou must call this->create_table_circa before calling this method.\n";}
  $sth->finish;
  $requete="select id,url,local_url,niveau,categorie from ".$self->prefix_table.$idp."links where parse='0' and valide=1 and local_url is not null order by id";
  $sth = $self->{DBH}->prepare($requete);
  $self->set_agent('local');
  if ($sth->execute())
    {
    my ($categorieAuto)=$self->get_first("select categorieAuto from ".$self->prefix_table."responsable where id=$idp");
    while (my ($id,$url,$local_url,$niveau,$categorie)=$sth->fetchrow_array)
      {
      my ($res,$nbw,$nbwg) = $self->look_at($url,$id,$idp,undef,$local_url,$categorieAuto,$niveau,$categorie);
      if ($res==-1) {$self->{DBH}->do("update ".$self->prefix_table.$idp."links set valide='0' where id=$id");}
      else {$nbAjout+=$res;$nbWords+=$nbw;$nb++;$nbWordsGood+=$nbwg;}
      }
    }
  else {print "\nYou must call this->create_table_circa before calling this method.\n";}
  $sth->finish;

  return ($nb,$nbAjout,$nbWords,$nbWordsGood);
  }

=item update($xj,[$idp])

Update url not visited since $xj days for account $idp. If idp is not
given, 1 will be used. Url never parsed will be indexed.

Return ($nb,$nbAjout,$nbWords,$nbWordsGood)

=over

=item *

$nb: Number of links find

=item  *

$nbAjout: Number of links added

=item *

$nbWords: Number of word find

=item *

$nbWordsGood: Number of word added

=back

=cut

sub update
  {
  my ($this,$xj,$idp)=@_;
  $this->set_agent;
  $idp = 1 if (!$idp);
  my ($nb,$nbAjout,$nbWords,$nbWordsGood)=(0,0,0,0);

  my $sub = sub
    {
    my ($this,$requete)=@_;
    my $sth = $this->{DBH}->prepare($requete);
    if ($sth->execute())
      {
      while (my ($id,$url,$last_update,$niveau,$categorie) =$sth->fetchrow_array)
        {
        my ($categorieAuto)=$this->get_first("select categorieAuto from ".$this->prefix_table."responsable where id=$idp");
        my ($res,$nbw,$nbwg) = $this->look_at($url,$id,$idp,$last_update,undef,$categorieAuto,$niveau,$categorie);
        if ($res==-1) {$this->{DBH}->do("update ".$this->prefix_table.$idp."links set valide='0' where id=$id");}
        else {$nbAjout+=$res;$nbWords+=$nbw;$nb++;$nbWordsGood+=$nbwg;}
        }
      }
    else {print "\nYou must call this->create_table_circa before calling this method.\n";}
    $sth->finish;
    };

  my $requete="
select id,url,UNIX_TIMESTAMP(last_update),niveau,categorie
from ".$this->prefix_table.$idp."links
where valide=1 AND PARSE='0'
order by url";
  $this->$sub($requete);

  $requete="
select id,url,UNIX_TIMESTAMP(last_update),niveau,categorie
from ".$this->prefix_table.$idp."links
where TO_DAYS(NOW()) >= (TO_DAYS(last_check) + $xj)
and local_url is null
and valide=1
order by url";
  $this->$sub($requete);

  $requete="
select id,url,UNIX_TIMESTAMP(last_update),local_url,niveau,categorie
from ".$this->prefix_table.$idp."links
where TO_DAYS(NOW()) >= (TO_DAYS(last_check) + $xj)
and local_url is not null
and valide=1
order by url";
  $this->$sub($requete);

  return ($nb,$nbAjout,$nbWords,$nbWordsGood);
  }

=item create_table_circa

Create tables needed by Circa - Cree les tables necessaires à Circa:

=over

=item *

categorie   : Catégories de sites

=item *

links       : Liste d'url

=item *

responsable : Lien vers personne responsable de chaque lien

=item *

relations   : Liste des mots / id site indexes

=item *

inscription : Inscriptions temporaires

=back

=cut

sub create_table_circa
  {
  my $self = shift;
  my $requete="
CREATE TABLE ".$self->prefix_table."responsable (
   id     int(11) DEFAULT '0' NOT NULL auto_increment,
   email  char(25) NOT NULL,
   titre  char(50) NOT NULL,
   categorieAuto tinyint DEFAULT '0' NOT NULL,
   masque  char(150) NOT NULL,
   PRIMARY KEY (id)
)";

  $self->{DBH}->do($requete) || print $DBI::errstr,"<br>\n";
  $requete="
CREATE TABLE ".$self->prefix_table."inscription (
   email  char(25) NOT NULL,
   url     varchar(255) NOT NULL,
   titre  char(50) NOT NULL,
   dateins  date
)";
  $self->{DBH}->do($requete) || print $DBI::errstr,"<br>\n";

  $requete="
CREATE TABLE ".$self->prefix_table."local_url (
   id  int(11)     NOT NULL,
   path  varchar(255) NOT NULL,
   url  varchar(255) NOT NULL
)";
  $self->{DBH}->do($requete) || print $DBI::errstr,"<br>\n";
  }

=item drop_table_circa

Drop all table in Circa ! Be careful ! - Detruit touted les tables de Circa

=cut

sub drop_table_circa
  {
  my $self = shift;
  my $sth = $self->{DBH}->prepare("select id from ".$self->prefix_table."responsable");
  $sth->execute() || print &header,$DBI::errstr,"<br>\n";
  while (my @row=$sth->fetchrow_array) {$self->drop_table_circa_id($row[0]);}
  $sth->finish;
  $self->{DBH}->do("drop table ".$self->prefix_table."responsable")|| print $DBI::errstr,"<br>\n";
  $self->{DBH}->do("drop table ".$self->prefix_table."inscription")|| print $DBI::errstr,"<br>\n";
  $self->{DBH}->do("drop table ".$self->prefix_table."local_url")  || print $DBI::errstr,"<br>\n";
  }

=item drop_table_circa_id

Detruit les tables de Circa pour l'utilisateur id

=cut

sub drop_table_circa_id
  {
  my $self = shift;
  my $id=$_[0];
  $self->{DBH}->do("drop table ".$self->prefix_table.$id."categorie")  || print $DBI::errstr,"<br>\n";
  $self->{DBH}->do("drop table ".$self->prefix_table.$id."links")      || print $DBI::errstr,"<br>\n";
  $self->{DBH}->do("drop table ".$self->prefix_table.$id."relation")   || print $DBI::errstr,"<br>\n";
  $self->{DBH}->do("drop table ".$self->prefix_table.$id."stats")      || print $DBI::errstr,"<br>\n";
  $self->{DBH}->do("delete from ".$self->prefix_table."responsable where id=$id");
  }

=item create_table_circa_id($id)

Create tables needed by Circa for instance $id:

=over

=item *

categorie   : Catégories de sites

=item *

links       : Liste d'url

=item *

relations   : Liste des mots / id site indexes

=item *

stats   : Liste des requetes

=back

=cut

sub create_table_circa_id
  {
  my $self = shift;
  my $id=$_[0];
  my $requete="
CREATE TABLE ".$self->prefix_table.$id."categorie (
   id     int(11) DEFAULT '0' NOT NULL auto_increment,
   nom     char(50) NOT NULL,
   parent   int(11) DEFAULT '0' NOT NULL,
   masque varchar(255),
   PRIMARY KEY (id)
   )";
  $self->{DBH}->do($requete) || print $DBI::errstr,"<br>\n";

  $requete="
CREATE TABLE ".$self->prefix_table.$id."links (
   id     int(11) DEFAULT '0' NOT NULL auto_increment,
   url     varchar(255) NOT NULL,
   local_url   varchar(255),
   titre   varchar(255) NOT NULL,
   description   blob NOT NULL,
   langue   char(6) NOT NULL,
   valide   tinyint DEFAULT '0' NOT NULL,
   categorie   int(11) DEFAULT '0' NOT NULL,
   last_check   datetime DEFAULT '0000-00-00' NOT NULL,
   last_update  datetime DEFAULT '0000-00-00' NOT NULL,
   parse   ENUM('0','1') DEFAULT '0' NOT NULL,
   browse_categorie ENUM('0','1') DEFAULT '0' NOT NULL,
   niveau   tinyint DEFAULT '0' NOT NULL,
   PRIMARY KEY (id),
   KEY id (id),
   UNIQUE id_2 (id),
   KEY id_3 (id),
   KEY url (url),
   UNIQUE url_2 (url),
   KEY categorie (categorie)
)";
  $self->{DBH}->do($requete) || print $DBI::errstr,"<br>\n";

  $requete="
CREATE TABLE ".$self->prefix_table.$id."relation (
   mot     char(30) NOT NULL,
   id_site   int(11) DEFAULT '0' NOT NULL,
   facteur   tinyint(4) DEFAULT '0' NOT NULL,
   KEY mot (mot)
)";
  $self->{DBH}->do($requete) || print $DBI::errstr,"<br>\n";
  $requete="
CREATE TABLE ".$self->prefix_table.$id."stats (
   id  int(11) DEFAULT '0' NOT NULL auto_increment,
   requete varchar(255) NOT NULL,
   quand datetime NOT NULL,
   PRIMARY KEY (id)
)";
  $self->{DBH}->do($requete) || print $DBI::errstr,"<br>\n";
  }

=item export($mysqldump)

Export data from Mysql in circa.sql

$mysqldump: path of bin of mysqldump. If not given, search in /usr/bin/mysqldump,
/usr/local/bin/mysqldump, /opt/bin/mysqldump

=cut

sub export
  {
  my ($self,$dump)=shift;
  my $pass;
  if ( (!$dump) || (! -x $dump))
    {
    if (-x "/usr/local/bin/mysqldump") {$dump = "/usr/local/bin/mysqldump" ;}
    elsif (-x "/usr/bin/mysqldump") {$dump = "/usr/bin/mysqldump" ;}
    elsif (-x "/opt/bin/mysqldump") {$dump = "/opt/bin/mysqldump" ;}
    else {$self->disconnect; die "Can't find mysqldump.\n";}
    }
  unlink "circa.sql" if (-w "circa.sql");
  my (@t,@exec);
  my $requete = "select id from ".$self->prefix_table."responsable";
  my $sth = $self->{DBH}->prepare($requete);
  $sth->execute;
  while (my ($id)=$sth->fetchrow_array) {push(@t,$id);}
  $sth->finish;
  if ($self->{_PASSWORD}) {$pass=" -p".$self->{_PASSWORD}.' ';}
  else {$pass=' ';}
  push(@exec,$dump." -u".$self->{_USER}.$pass.$self->{_DB}." ".$self->prefix_table."responsable >> circa.sql");
  push(@exec,$dump." -u".$self->{_USER}.$pass.$self->{_DB}." ".$self->prefix_table."local_url >> circa.sql");
  push(@exec,$dump." -u".$self->{_USER}.$pass.$self->{_DB}." ".$self->prefix_table."inscription >> circa.sql");
  foreach my $id (@t)
    {
    push(@exec,$dump." -u".$self->{_USER}.$pass.$self->{_DB}." ".$self->prefix_table.$id."categorie >> circa.sql");
    push(@exec,$dump." -u".$self->{_USER}.$pass.$self->{_DB}." ".$self->prefix_table.$id."links >> circa.sql");
    push(@exec,$dump." -u".$self->{_USER}.$pass.$self->{_DB}." ".$self->prefix_table.$id."relation >> circa.sql");
    push(@exec,$dump." -u".$self->{_USER}.$pass.$self->{_DB}." ".$self->prefix_table.$id."stats >> circa.sql");
    }
  $|=1;
  print "En cours d'export ...";
  foreach (@exec) {system($_) ==0 or print "Ca pine:$?\n";}
  print "done.\n";
  }

=item import_data($mysql)

Import data in Mysql from circa.sql

$mysql : path of bin of mysql. If not given, search in /usr/bin/mysql,
/usr/local/bin/mysql, /opt/bin/mysql

=cut

sub import_data
  {
  my ($self,$dump)=shift;
  if ( (!$dump) || (! -x $dump))
    {
    if (-x "/usr/local/bin/mysql") {$dump = "/usr/local/bin/mysql" ;}
    elsif (-x "/usr/bin/mysql") {$dump = "/usr/bin/mysql" ;}
    elsif (-x "/opt/bin/mysql") {$dump = "/opt/bin/mysql" ;}
    else {$self->disconnect; die "Can't find mysql.\n";}
    }
  $|=1;
  print "En cours d'import ...";
  my $c = $dump." -u".$self->{_USER};
  $c.=" -p".$self->{_PASSWORD} if ($self->{_PASSWORD});
  $c.=" ".$self->{_DB}." < circa.sql";
  system($c) == 0 or print "Ca pine:$?\n";
  print "done.\n";
  }

=back

=head2 Method for administrate each account

=over

=item admin_compte($compte)

Return list about account $compte

Retourne une liste d'elements se rapportant au compte $compte

=over

=item *

$responsable  : Adresse mail du responsable

=item *

$titre    : Titre du site pour ce compte

=item *

$nb_page  : Number of url added to Circa - Nombre de page pour ce site

=item *

$nb_words : Number of world added to Circa - Nombre de mots indexés

=item *

$last_index  : Date of last indexation. Date de la dernière indexation

=item *

$nb_requetes  : Number of request aked - Nombre de requetes effectuées sur ce site

=item *

$racine  : First page added - 1ere page inscrite

=back

=cut

sub admin_compte
  {
  my ($self,$compte)=@_;
  my ($responsable,$titre) = $self->get_first("select email,titre from ".$self->prefix_table."responsable where id=$compte");
  my ($racine)                    = $self->get_first("select min(id) from ".$self->prefix_table.$compte."links");
  ($racine)                          = $self->get_first("select url from ".$self->prefix_table.$compte."links where id=$racine");
  my ($nb_page)                = $self->get_first("select count(1) from ".$self->prefix_table.$compte."links");
  my ($last_index)              = $self->get_first("select max(last_check) from ".$self->prefix_table.$compte."links");
  my ($nb_requetes)          = $self->get_first("select count(1) from ".$self->prefix_table.$compte."stats");
  my ($nb_words)              = $self->get_first("select count(1) from ".$self->prefix_table.$compte."relation");
  return ($responsable,$titre,$nb_page,$nb_words,$last_index,$nb_requetes,$racine);
  }

=item most_popular_word($max,$id)

Retourne la reference vers un hash representant la liste
des $max mots les plus présents dans la base de reponsable $id

=cut

sub most_popular_word
  {
  my $self = shift;
  my ($max,$id)=@_;
  $id =1 if (!$id);
  my %l;
  my $requete = "select mot,count(1) from ".$self->prefix_table.$id."relation r group by r.mot order by 2 desc limit 0,$max";
  my $sth = $self->{DBH}->prepare($requete);
  $sth->execute;
  while (my ($word,$nb)=$sth->fetchrow_array) {$l{$word}=$nb;}
  $sth->finish;
  return \%l;
  }

=item stat_request($id)

Return some statistics about request make on Circa

=cut

sub stat_request
  {
  my ($self,$id)=@_;
  my (%l1,%l2);
  my $requete = "select count(1), DATE_FORMAT(quand, '%e/%m/%y') as d from ".$self->prefix_table.$_[1]."stats group by d order by d";
  my $sth = $self->{DBH}->prepare($requete);
  $sth->execute;
  while (my ($nb,$word)=$sth->fetchrow_array) {$l1{$word}=$nb;}
  $sth->finish;

  $requete = "select requete,count(requete) from ".$self->prefix_table.$_[1]."stats group by 1 order by 2 desc limit 0,10";
  $sth = $self->{DBH}->prepare($requete);
  $sth->execute;
  while (my ($word,$nb)=$sth->fetchrow_array) {$l2{$word}=$nb;}
  $sth->finish;

  return (\%l1,\%l2);
  }

=item delete_url($compte,$id_url)

Delete url with id $id_url on account $compte

Supprime le lien $id_url de la table $compte/relation et $compte/links

=cut

sub delete_url
  {
  my ($this,$compte,$id_url)=@_;
  $this->{DBH}->do("delete from ".$this->prefix_table.$compte."relation where id_site = $id_url");
  $this->{DBH}->do("delete from ".$this->prefix_table.$compte."links where id = $id_url");
  }

=item valide_url($compte,$id_url)

Commit link $id_url on table $compte/links

Valide le lien $id_url

=cut

sub valide_url
  {
  my ($this,$compte,$id_url)=@_;
  $this->{DBH}->do("update ".$this->prefix_table.$compte."links set valide=1 where id = $id_url");
  }

=item masque_categorie($compte,$id,$file)

Use a different masque for browse this categorie

=cut

sub masque_categorie
  {
  my ($this,$compte,$id,$file)=@_;
  $this->{DBH}->do("update ".$this->prefix_table.$compte."categorie set masque='$file' where id = $id");
  }

=item delete_categorie($compte,$id)

Supprime la categorie $id pour le compte de responsable $compte et
tous les liens et relation qui sont dans cette categorie

=cut

sub delete_categorie
  {
  my ($self,$compte,$id)=@_;
  my $sth = $self->{DBH}->prepare("select id from ".$self->prefix_table.$compte."links where categorie=$id");
  $sth->execute || print &header,"Erreur:delete_categorie:$DBI::errstr<br>";
  # Pour chaque categorie
  while (my @row = $sth->fetchrow_array)
    {$self->{DBH}->do("delete from ".$self->prefix_table.$compte."relation where id_site = $row[0]");}
  $sth->finish;
  $self->{DBH}->do("delete from ".$self->prefix_table.$compte."links where categorie = $id");
  $self->{DBH}->do("delete from ".$self->prefix_table.$compte."categorie where id = $id");
  }

=item rename_categorie($compte,$id,$nom)

Rename category $id for account $compte in $name

Renomme la categorie $id pour le compte $compte en $nom

=cut

sub rename_categorie
  {
  my ($this,$compte,$id,$nom)=@_;
  $this->{DBH}->do("update ".$this->prefix_table.$compte."categorie set nom='$nom' where id = $id")|| print "Erreur:$DBI::errstr<br>\n";
  }

=item deplace_categorie($compte,$id1,$id2)

Move url for account $compte from one categorie $id1 to another $id2

=cut

sub deplace_categorie
  {
  my ($this,$compte,$id1,$id2)=@_;
  $this->{DBH}->do("update ".$this->prefix_table.$compte."links set categorie=$id2 where categorie = $id1")|| print "Erreur:$DBI::errstr<br>\n";
  }

=item add_site($url,[$idMan],[$local_url],[$browse_categorie],[$niveau],[$categorie])

Ajoute un site à la table links.

=over

=item *

$url : Url de la page à ajouter

=item *

$idMan : Id dans la table responsable du responsable de ce site
Si non present, positionné à 1.

=item *

$local_url : Url accessible par file:// pour les documents pouvant être
indexé en local

=item *

$browse_categorie : 0 ou 1. (Apparait ou pas dans la navigation par
categorie). Si non present, 0.

=item *

$niveau : Profondeur de l'indexation pour ce document. Si non present,
positionné à 0.

=item *

$categorie : Categorie de cet url. Si non present, positionné à 0.

=back

Si une erreur est trouvée, $DBI::errstr est positionnée et 0 est retourné.
1 sinon.

=cut

sub add_site
  {
  my ($self,$url,$idMan,$local_url,$browse_categorie,$niveau,$categorie)=@_;
  $idMan=1 if (!$idMan);
  $niveau=0 if (!$niveau);
  chop ($url) if ($url=~/\/$/);
  my ($req1,$req2) = ("insert into ".$self->prefix_table.$idMan."links(url,titre,description,niveau,valide",
          "values ('$url',' ',' ',$niveau,1");
  if ($local_url) {$req1.=',local_url';$req2.=",'$local_url'";}
  if ($browse_categorie) {$req1.=',browse_categorie';$req2.=",'1'";}
  if ($categorie) {$req1.=',categorie';$req2.=",$categorie";}
  $req1.=') ';$req2.=")";
  #print "requete:$req1 $req2<br>";
  $self->{DBH}->do($req1.$req2) || return 0; #print &header,$req1,$req2,$DBI::errstr,"<br>\n";
  #print "Add $url<br>\n";
  if ($DBI::errstr) {return 0;}
  else { return 1;}
  }

=item inscription($email,$url,$titre)

Inscrit un site dans une table temporaire

=cut

sub inscription {$_[0]->do("insert into ".$_[0]->prefix_table."inscription values ('$_[1]','$_[2]','$_[3]',CURRENT_DATE)");}

=back

=head2 HTML functions

=over

=item start_classic_html

Affiche le debut de document (<head></head>)

=cut

sub start_classic_html
  {
  my ($self,$cgi)=@_;
  return $cgi->start_html(
    -'title'  => 'Circa',
    -'author'  => 'alian@alianwebserver.com',
    -'meta'    => {'keywords'=>'circa,recherche,annuaire,moteur',
          -'copyright'  => 'copyright 1997-2000 AlianWebServer'},
    -'dtd'    => '-//W3C//DTD HTML 4.0 Transitional//EN" "http://www.w3.org/TR/REC-html40/loose.dtd')."\n";
  }

=item header_compte

Function use with CGI admin_compte.cgi. Display list of features of admin_compte.cgi

=cut

sub header_compte
  {
  my ($self,$cgi,$compte,$script)=@_;
  my $buf='<ul>'."\n";
  $buf.=$cgi->li("<a href=\"$script?compte=$compte\">Infos générales</a>")."\n";
  $buf.=$cgi->li("<a href=\"$script?compte=$compte&ecran_stats=1\">Statistiques</a>")."\n";
  $buf.=$cgi->li("<a href=\"$script?compte=$compte&ecran_urls=1\">Gestion des url</a>")."\n";
  $buf.=$cgi->li("<a href=\"$script?compte=$compte&ecran_validation=1\">Validation des url</a>")."\n";
  $buf.=$cgi->li("<a href=\"$script?compte=$compte&ecran_categorie=1\">Gestion des categories</a>")."\n";
  $buf.='</ul>'."\n";
  return $buf;
  }

=item get_liste_liens($id)

Rend un buffer contenant une balise select initialisée avec les données
de la table links responsable $id

=cut

sub get_liste_liens
  {
  my ($self,$id,$cgi)=@_;
  my %tab;
  my $sth = $self->{DBH}->prepare("select id,url from ".$self->prefix_table.$id."links");
  $sth->execute() || print &header,$DBI::errstr,"<br>\n";
  while (my @row=$sth->fetchrow_array)
    {
    $self->set_host_indexed($row[1]);
    my $racine=$self->host_indexed;
    $tab{$row[0]}=$row[1];
    $tab{$row[0]}=~s/www\.//g;
    }
  $sth->finish;
  my @l =sort { $tab{$a} cmp $tab{$b} } keys %tab;
  return $cgi->scrolling_list(  -'name'=>'id',
                           -'values'=>\@l,
                           -'size'=>1,
                           -'labels'=>\%tab);
        }


=item get_liste_liens_a_valider($id)

Rend un buffer contenant une balise select initialisée avec les données
de la table links responsable $id liens non valides

=cut

sub get_liste_liens_a_valider
  {
  my ($self,$id,$cgi)=@_;
  my (%tab,$buf);
  $buf='<table>';
  my $sth = $self->{DBH}->prepare("select id,url from ".$self->prefix_table.$id."links where valide=0");
  $sth->execute() || print &header,$DBI::errstr,"<br>\n";
  while (my @row=$sth->fetchrow_array)
    {
    $self->set_host_indexed($row[1]);
    my $racine=$self->host_indexed;
    $tab{$row[0]}=$row[1];
    $tab{$row[0]}=~s/www\.//g;
    }
  $sth->finish;
  my @l =sort { $tab{$a} cmp $tab{$b} } keys %tab;
  foreach (@l)  {$buf.=$cgi->Tr($cgi->td("<input type=\"radio\" name=\"id\" value=\"$_\">"),$cgi->td("<a target=_blank href=\"$tab{$_}\">$tab{$_}</a>"))."\n";}
  $buf.='</table>';
  return $buf;
        }

=item get_liste_site

Rend un buffer contenant une balise select initialisée avec les données
de la table responsable

=cut

sub get_liste_site
  {
  my ($self,$cgi)=@_;
  my %tab;
  my $sth = $self->{DBH}->prepare("select id,email,titre from ".$self->prefix_table."responsable");
  $sth->execute() || print &header,$DBI::errstr,"<br>\n";
  while (my @row=$sth->fetchrow_array) {$tab{$row[0]}="$row[1]/$row[2]";}
  $sth->finish;
  my @l =sort { $tab{$a} cmp $tab{$b} } keys %tab;
  return $cgi->scrolling_list(  -'name'=>'id',
                             -'values'=>\@l,
                             -'size'=>1,
                             -'labels'=>\%tab);
        }

=item get_liste_categorie($id,$cgi)

Return two references to a list and a hash.
The hash have name of categorie as key, and number of site in this categorie as value.
The list is ordered keys of hash.

=cut

sub get_liste_categorie
  {
  my ($self,$id,$cgi)=@_;
  my (%tab,%tab2,$erreur);
  my $sth = $self->{DBH}->prepare("select id,nom,parent from ".$self->prefix_table.$id."categorie");
  $sth->execute() || return;
  while (my @row=$sth->fetchrow_array) {$tab2{$row[0]}[0]=$row[1];$tab2{$row[0]}[1]=$row[2];}
  $sth->finish;

  $sth = $self->{DBH}->prepare("select count(1),categorie from ".$self->prefix_table.$id."links group by categorie");
  $sth->execute() || return;
  while (my @row=$sth->fetchrow_array) {$tab{$row[1]}=$row[0];}
  $sth->finish;
  if (!$tab2{0}) {$tab2{0}[0]='Racine';$tab2{0}[1]=0;}
  foreach (keys %tab2) {$tab{$_}= getParent($_,%tab2)." (".($tab{$_}||0).")";}
  my @l =sort { $tab{$a} cmp $tab{$b} } keys %tab;
  return (\@l,\%tab);
  }

=item get_liste_mot($compte,$id)

Give word indexed on url $id on table $prefix.$compte.links.
Return a buffer with words separated by space.

=cut

sub get_liste_mot
  {
  my ($self,$compte,$id)=@_;
  my @l;
  my $sth = $self->{DBH}->prepare("select mot from ".$self->prefix_table.$compte."relation where id_site=$id");
  $sth->execute() || print "Erreur: $DBI::errstr\n";
  while (my ($l)=$sth->fetchrow_array) {push(@l,$l);}
  return join(' ',@l);
  }

sub get_liste_langues
  {
  my ($self,$id,$valeur,$cgi)=@_;
  my @l;
  my $sth = $self->{DBH}->prepare("select distinct langue from ".$self->{PREFIX_TABLE}.$id."links");
  $sth->execute() || print "Erreur: $DBI::errstr\n";
  while (my ($l)=$sth->fetchrow_array) {push(@l,$l);}
  $sth->finish;
  my %langue=(
    'unkno'=>'unkno',
      'da'=>'Dansk',
    'de'=>'Deutsch',
    'en'=>'English',
    'eo'=>'Esperanto',
      'es'=>'Espanõl',
      'fi'=>'Suomi',
    'fr'=>'Francais',
      'hr'=>'Hrvatski',
      'hu'=>'Magyar',
    'it'=>'Italiano',
        'nl'=>'Nederlands',
      'no'=>'Norsk',
      'pl'=>'Polski',
        'pt'=>'Portuguese',
      'ro'=>'Românã',
        'sv'=>'Svenska',
      'tr'=>'TurkCe',
    '0'=>'All'
    );
  my $scrollLangue =
    $cgi->scrolling_list(  -'name'=>'langue',
                             -'values'=>\@l,
                             -'size'=>1,
                             -'default'=>$valeur,
                             -'labels'=>\%langue);
  }



=item fill_template($masque,$vars)

 $masque : Chemin du template
 $vars : reference du hash des noms/valeurs à substituer dans le template

Give template with variables replaced..
Ex: si $$vars{age}=12, et que le fichier $masque contient la chaine:

  J'ai <? $age ?> ans,

la fonction rendra

  J'ai 12 ans,

=back

=cut

sub fill_template
  {
  my ($self,$masque,$vars)=@_;
  open(FILE,$masque) || die "Can't read $masque<br>";
  my @buf=<FILE>;
  close(FILE);
  while (my ($n,$v)=each(%$vars))
    {
    if (defined($v)) {map {s/<\? \$$n \?>/$v/gm} @buf;}
    else {map {s/<\? \$$n \?>//gm} @buf;}
    }
  return join('',@buf);
  }


=head2 Private methods

=over

=item look_at ($url,$idc,$idr,$lastModif,$url_local,$categorieAuto,$niveau,$categorie)

Index an url. Job done is:

=over

=item *

Test if url used is valid. Return -1 else

=item *

Get the page and add each words found with weight set in constructor.

=item *

If maximum level of links is not reach, add each link found for the next indexation

=back

Parameters:

=over

=item *

$url : Url to read

=item *

$idc: Id of url in table links

=item *

$idr : Id of account's url

=item *

$lastModif (optional) : If this parameter is set, Circa didn't make any job
on this page if it's older that the date.

=item *

$url_local (optional) Local url to reach the file

=item *

$categorieAuto (optional) If $categorieAuto set to true, Circa will
create/set the category of url with syntax of directory found. Ex:

http://www.alianwebserver.com/societe/stvalentin/index.html will create
and set the category for this url to Societe / StValentin

If $categorieAuto set to false, $categorie will be used.

=item *

$niveau (optional) Level of actual link.

=item *

$categorie (optional) See $categorieAuto.

=back

Return (-1,0) if url isn't valide, number of word and number of links  found else

=cut

sub look_at
  {
  my($this,$url,$idc,$idr,$lastModif,$url_local,$categorieAuto,$niveau,$categorie) = @_;
  my ($l,$url_orig,$racineFile,$racineUrl,$lastUpdate);
  if ($url_local)
    {
    $this->{ConfigMoteur}->{'temporate'}=0;
    if ($url_local=~/.*\/$/)
      {
      chop($url_local);
      if (-e "$url_local/index.html") {$url_local.="/index.html";}
      elsif (-e "$url_local/index.htm") {$url_local.="/index.htm";}
      elsif (-e "$url_local/default.htm") {$url_local.="/default.htm";}
      else {return (-1,0,0);}
      }
    $url_orig=$url;
    $url=$url_local;
    ($racineFile,$racineUrl) = $this->get_first("select path,url from ".$this->prefix_table."local_url where id=$idr");
    }
  print "Analyse de $url<br>\n";

  my ($nb,$nbwg,$nburl)=(0,0,0);
  if ($url_local) {$this->set_host_indexed($url_local);}
  else {$this->set_host_indexed($url);}
  my $analyseur = HTML::LinkExtor->new(undef,$url);

  # Creation d'une requete
  # On passe la requete à l'agent et on attend le résultat
  my $res = $this->{AGENT}->request(new HTTP::Request('GET' => $url));
  #print "<strong>Url :</strong>",$url,"<br>\n";
  if ($res->is_success)
    {
    # Langue
    my $language = $res->content_language || 'unkno';
    # Date derniere modif
    if ((!$lastModif)||(!$res->last_modified)||($lastModif<$res->last_modified))
      {
      if ($res->last_modified)
        {
        my @date = localtime($res->last_modified);
        $lastUpdate = ($date[5]+1900).'-'.($date[4]+1).'-'.$date[3].' '.$date[2].':'.$date[1].':'.$date[0];
        }
      else {$lastUpdate='0000-00-00';}
      #system('/bin/ps m|grep perl>>/tmp/ressource');
      # Mots clefs et description
      my ($keyword,$desc)=get_meta($res->content);
      # Titre
      my $titre = $res->title || $url;
      $titre=~s/'/\\'/g if ($titre);
      # Categorie
      if ($categorieAuto) {$categorie = $this->get_categorie($url,$idr);}
      if (!$categorie) {$categorie=0;}
      my $requete ="
        update   ".$this->prefix_table.$idr."links
        set   parse    = '1',
          titre    = '$titre',
          description  = '$desc',
          last_update  = '$lastUpdate',
          last_check  = CURRENT_TIMESTAMP,
          langue    = '$language',
          categorie  = $categorie
        where id=$idc";
      $this->{DBH}->do($requete) || print "Erreur $requete:$DBI::errstr<br>\n";

      # html2txt
      my $text = $res->content;
      $text=~s{ <! (.*?) (--.*?--\s*)+(.*?)> } {if ($1 || $3) {"<!$1 $3>";} }gesx;
      $text=~s{ <(?: [^>'"] * | ".*?" | '.*?' ) + > }{}gsx;
      $text=decode_entities($text);

      # Traitement des mots trouves
      $l = analyse_data($keyword,  $this->{ConfigMoteur}->{'facteur_keyword'},  %$l);
      $l = analyse_data($desc,     $this->{ConfigMoteur}->{'facteur_description'},  %$l);
      $l = analyse_data($titre,    $this->{ConfigMoteur}->{'facteur_titre'},    %$l);
      $l = analyse_data($text,  $this->{ConfigMoteur}->{'facteur_full_text'},  %$l);
      $l = analyse_data($url,  $this->{ConfigMoteur}->{'facteur_url'},  %$l);
      $this->{DBH}->do("delete from ".$this->prefix_table.$idr."relation where id_site = $idc");

      # Chaque mot trouve plus de $ConfigMoteur{'nb_min_mots'} fois
      # est enregistre
      while (my ($mot,$nb)=each(%$l))
        {
        my $requete = "insert into ".$this->prefix_table.$idr."relation (mot,id_site,facteur) values ('$mot',$idc,$nb)";
        if ($nb >=$this->{'ConfigMoteur'}{'nb_min_mots'}) {$this->{DBH}->do($requete);$nbwg++;}
        }
      my $nbw=keys %$l;undef(%$l);

      # On n'indexe pas les liens si on est au niveau max
      if ($niveau == $this->{ConfigMoteur}->{'niveau_max'})
        {
        print "Niveau max atteint. Liens suivants de cette page ignorés<br>\n" if ($this->{DEBUG});
        return (0,0,0);
        }
        # Traitement des url trouves
      $analyseur->parse($res->content);
      my @l = $analyseur->links;
      foreach my $var (@l)
        {
        $$var[2] = $this->check_links($$var[0],$$var[2]);
        if (($url_local) && ($$var[2]))
          {
          my $urlb = $$var[2];
          $urlb=~s/$racineFile/$racineUrl/g;
          #print h1("Ajout site local:$$var[2] pour $racineFile");
          $this->add_site($urlb,$idr,$$var[2],undef,$niveau+1,$categorie) && $nburl++;
          }
        elsif ($$var[2]) {$this->add_site($$var[2],$idr,undef,undef,$niveau+1,$categorie);$nburl++;}
        }
      return ($nburl,$nbw,$nbwg);
      }
    elsif ($res->content_length>$this->size_max)
      {print "Fichier trop grand:",ceil($res->content_length/1000000)," Mo<br>\n";}
    # Fichier non modifie depuis la derniere indexation
    else
      {
      print "Aucune modification depuis la dernière indexation sur $url<br>\n" if ($this->{DEBUG});
      $this->{DBH}->do("update ".$this->prefix_table.$idr."links set last_check = CURRENT_TIMESTAMP where id=$idc");
      return (0,0,0);
      }
    }
  # Sinon previent que URL defectueuse
  else {print "Url non valide:$url\n";return (-1,0,0);}
  }

=item get_meta($entete)

Parse et rend les meta-mots-clef et la meta-description de la page
HTML contenu dans $entete

=cut

sub get_meta
  {
  my($entete)=@_;
  my($desc,$mots,$a,$b,$c,$d,$e);
  return if (!defined($entete));
  $entete=~s/\r/ /g;
  $entete=~s/\n//g;
  $entete =~ tr/A-Z/a-z/;
  $entete=lc($entete);

  $a = index($entete,"name=\"description\" content=\"");
  $b = length("name=\"description\" content=\"");
  if ($a>-1)
    {
    $c = substr($entete,$a+$b);
    $d = index($c,"\">");
    $e = substr($c,0,$d);
    }
  $desc=$e || ' ';

  $a = index($entete,"name=\"keywords\" content=\"");
  $b = length("name=\"keywords\" content=\"");
  if ($a>-1)
    {
    $c = substr($entete,$a+$b);
    $d = index($c,"\">");
    $e = substr($c,0,$d);
    }
  $mots=$e;
  $mots=~s/'/\\'/g if ($mots);
  $desc=~s/'/\\'/g if ($desc);
  return($mots,$desc);
  }

=item analyse_data($data,$facteur,%l)

Recupere chaque mot du buffer $data et lui attribue une frequence d'apparition.
Les resultats sont ranges dans le tableau associatif passé en paramètre.
Les résultats sont rangés sous la forme %l=('mots'=>facteur).

=over

=item *

$data : buffer à analyser

=item *

$facteur : facteur à attribuer à chacun des mots trouvés

=item *

%l : Tableau associatif où est rangé le résultat

=back

Retourne la référence vers le hash

=cut

sub analyse_data
  {
  my ($data,$facteur,%l) = @_;
  if ($data)
    {
    # Ponctuation et mots recurents
    $data=~s/[\s\t]+/ /gm;
    $data=~s/http:\/\// /gm;
    $data=~tr/.;:,?!()"'[]#=\/_/ /;
    my @ex = split(/\s/,$data);
    foreach my $e (@ex)
      {
      next if !$e;
      $e=lc($e);
      if (($e =~/\w/)&&(length($e)>2)&&(!$bad{$e})) {$l{$e}+=$facteur;}
      }
    }
  return \%l;
  }

=item getParent($id,%tab)

Rend la chaine correspondante à la catégorie $id avec ses rubriques parentes

=cut

sub getParent
  {
  my ($id,%tab)=@_;
  my $parent;
  if (($tab{$id}[1]!=0)&&($tab{$id}[0]))
    {$parent = &getParent($tab{$id}[1],%tab);}
  if (!$tab{$id}[0]) {$tab{$id}[0]='Home';}
  $parent.=">$tab{$id}[0]";
  return $parent;
  }

=item set_agent

Set user agent for Circa robot. If local url (file://), LWP::UserAgent will be used.
Else LWP::RobotUA is used.

=cut

sub set_agent
  {
  my ($self,$locale,$bytes)=@_;
  if (($self->{ConfigMoteur}->{'temporate'}) && (!$locale))
    {
    $self->{AGENT} = new LWP::RobotUA 'CircaIndexer / $Revision: 1.11 $', $self->{ConfigMoteur}->{'author'};
    $self->{AGENT}->delay(10/60.0);
    }
  else {$self->{AGENT} = new LWP::UserAgent 'CircaIndexer / $Revision: 1.11 $', $self->{ConfigMoteur}->{'author'};}
  if ($self->{PROXY}) {$self->{AGENT}->proxy(['http', 'ftp'], $self->{PROXY});}
  $self->{AGENT}->max_size($self->size_max) if $self->size_max;
  $self->{AGENT}->timeout(25); # Set timeout to 25s (defaut 180)
  }

sub get_categorie
  {
  my ($self,$rep,$responsable) = @_;
  my $ori = $self->host_indexed;
  $rep=~s/$ori//g;
  #print $rep," et ", $self->host_indexed,"<br>";
  my @l = split(/\//,$rep);
  my $parent=0;
  my $regexp = qr/\.(htm|html|txt|java)$/;
  foreach (@l) {if (($_) && ($_ !~ $regexp)) {$parent = $self->create_categorie($_,$parent,$responsable);}}
  return $parent;
  }

sub create_categorie
  {
  my ($self,$nom,$parent,$responsable)=@_;
  $nom=ucfirst($nom);
  $nom=~s/_/ /g;
  my $id;
  if ($nom) {($id) = $self->get_first("select id from ".$self->prefix_table.$responsable."categorie where nom='$nom' and parent=$parent");}
  if ((!$id) && (defined $parent))
    {
    my $sth = $self->{DBH}->prepare("insert into ".$self->prefix_table.$responsable."categorie(nom,parent) values('$nom',$parent)");
    $sth->execute || print &header,"Erreur insert into ".$self->prefix_table.$responsable."categorie(nom,parent) values('$nom',$parent) : $DBI::errstr<br>";
    $sth->finish;
    $id = $sth->{'mysql_insertid'};
    }
  return $id || 0;
  }

=item check_links($tag,$links)

Check if url $links will be add to Circa. Url must begin with $self->host_indexed,
and his extension must be not doc,zip,ps,gif,jpg,gz,pdf,eps,png,deb,xls,ppt,class,
GIF,css,js,wav,mid.

If $links is accepted, return url. Else return 0.

=cut

sub check_links
  {
       my($self,$tag,$links) = @_;
       my $host = $self->host_indexed;
       my $bad = qr/\.(doc|zip|ps|gif|jpg|gz|pdf|eps|png|deb|xls|ppt|class|GIF|css|js|wav|mid)$/i;
  if (($tag) && ($links) && ($tag eq 'a') && ($links=~/^$host/) && ($links !~ $bad))
    {
    if ($links=~/^(.*?)#/) {$links=$1;} # Don't add anchor
    if ((!$self->{ConfigMoteur}->{'indexCgi'})&&($links=~/^(.*?)\?/)) {$links=$1;}
    return $links;
    }
  return 0;
   }

=item get_first($requete)

Retourne la premiere ligne du resultat de la requete $requete sous la forme d'un tableau

=back

=cut

sub get_first
  {
  my ($self,$requete)=@_;
  my $sth = $self->{DBH}->prepare($requete);
  $sth->execute || print &header,"Erreur:$requete:$DBI::errstr<br>";
  # Pour chaque categorie
  my @row = $sth->fetchrow_array;
  $sth->finish;
  return @row;
  }

sub header {return "Content-Type: text/html\n\n";}

=head1 AUTHOR

Alain BARBET alian@alianwebserver.com

=cut
