package Circa::Indexer;

# module Circa::Indexer : provide function to administrate Circa
# Copyright 2000 A.Barbet alian@alianwebserver.com.  All rights reserved.

# $Log: Indexer.pm,v $
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
$VERSION = ('$Revision: 1.7 $ ' =~ /(\d+\.\d+)/)[0];

=head1 NAME

Circa::Indexer - provide functions to administrate Circa, 
a www search engine running with Mysql

=head1 SYNOPSIS

 use Circa::Indexer;
 my $indexor = new Circa::Indexer;
 
 # Connection à MySQL
 if (!$indexor->connect_mysql($user,$pass,$db)) 
	{die "Erreur à la connection MySQL:$DBI::errstr\n";}
	
 # Creation des tables de Circa
 $indexor->create_table_circa;
 
 # Suppression des tables de Circa
 $indexor->drop_table_circa;
 
 # Ajout d'un site
 $indexor->addSite("http://www.alianwebserver.com/",
                   'alian@alianwebserver.com',
                   "Alian Web Server");
                   
 # Indexation (mots et url) des liens non encore parsé sur le premier site inscrit                  
 my ($nbIndexe,$nbAjoute,$nbWords,$nbWordsGood) = $indexor->parse_new_url(1);
 print 	"$nbIndexe pages indexées,"
 	"$nbAjoute pages ajoutées,"
 	"$nbWordsGood mots indexés,"
 	"$nbWords mots lus\n";

 # Interroge les pages qui n'ont pas été parsées depuis plus de 1 mois sur le
 # premier site inscrit
 $indexor->update(30,1);

Voir également les fichier admin.pl et admin.cgi

=head1 DESCRIPTION

This is Circa::Indexer, a module who provide functions 
to administrate Circa, a www search engine running with 
Mysql. Circa is for your Web site, or for a list of sites. 
It indexes like Altavista does. It can read, add and 
parse all url's found in a page. It add url and word 
to MySQL for use it at search.

This module can:

=over 3

=item Add url

=item Index words

=item Parse url, and so on.

=back 

Remarques:
 - This file are not added : doc,zip,ps,gif,jpg,gz,pdf,eps
 - Weight for each word is in hash $ConfigMoteur

=head1 VERSION

$Revision: 1.7 $

=cut

########## CONFIG  ##########
my $temporate = 1;# Temporise les requetes sur le serveur d'une minute. 
		  # A modifier que si vous êtes l'administrateur de votre serveur !
my $indexCgi = 0; # Suite les différents liens des CGI (ex: ?nom=toto&riri=eieiei)
my $author = 'alian@alianwebserver.com'; # Responsable du moteur
my %ConfigMoteur=(
	'facteur_keyword'	=>15,
	'facteur_description'	=>10,
	'facteur_titre'		=>10,
	'facteur_full_text'	=>1,
	'nb_min_mots'		=>2
	); # Poid des differentes parties d'un doc HTML
my %bad = map {$_ => 1} qw (
	le la les et des de and or the un une ou qui que quoi a an 
	&quot je tu il elle nous vous ils elles eux ce cette ces cet celui celle ceux 
	celles qui que quoi dont ou mais ou et donc or ni car parceque un une des pour 
	votre notre avec sur par sont pas mon ma mes tes ses the from for and our my 
	his her and your to in that else also with this you date not has net but can 
	see who dans est \$ { & com/ + /); # Mot à ne pas indexer
########## FIN CONFIG  ##########

sub new {
        my $class = shift;
        my $self = {};
        bless $self, $class;     
        $self->{SERVER_PORT}  ="3306"; 	# Port de mysql par default
	$self->{SIZE_MAX}     = 1000000;  # Size max of file read
	$self->{PREFIX_TABLE} = 'circa_';
	$self->{HOST_INDEXED} = undef;
	$self->{DBH} = undef;
	$self->{PROXY} = undef;
        return $self;
    	}

=head1 Manipulation des attributs

=head2 size_max($size)

Get or set size max of file read by indexer (For avoid memory pb).

=cut

sub size_max($size)
	{
	my $self = shift;
	if (@_) {$self->{SIZE_MAX}=shift;}
	return $self->{SIZE_MAX};
	}

=head2 set_agent

=cut

sub set_agent
	{
	my ($self,$locale,$bytes)=@_;
	if (($temporate) && (!$locale))
		{
		$self->{AGENT} = new LWP::RobotUA 'CircaIndexer/0.1', $author;
		$self->{AGENT}->delay(10/60.0);
		}
	else {$self->{AGENT} = new LWP::UserAgent 'CircaIndexer/0.1', $author;}
	if ($self->{PROXY}) {$self->{AGENT}->proxy(['http', 'ftp'], $self->{PROXY});}
	$self->{AGENT}->max_size($self->size_max) if $self->size_max;
	}

=head2 port_mysql($port)

Get or set the MySQL port

=cut

sub port_mysql
	{
	my $self = shift;
	if (@_) {$self->{SERVER_PORT}=shift;}
	return $self->{SERVER_PORT};
	}

=head2 host_indexed($host)

Get or set the host indexed.

=cut

sub host_indexed($host)
	{
	my $self = shift;
	if (@_) {$self->{HOST_INDEXED}=shift;}
	return $self->{HOST_INDEXED};		
	}

sub set_host_indexed($url)
	{
	my $this=shift;
	my $url=$_[0];
	if ($url=~/^(http:\/\/.*?)\//) {$this->host_indexed($1);}
	elsif ($url=~/^(file:\/\/\/.*?)\//) {$this->host_indexed($1);}
	else {$this->host_indexed($url);}
	}

=head2 proxy($adr_proxy)

Positionne le proxy a utiliser le cas écheant.

 $adr_proxy : Ex: 'http://proxy.sn.no:8001/'

=cut

sub proxy
	{
	my $self = shift;
	if (@_) {$self->{PROXY}=shift;}
	return $self->{PROXY};
	}

=head2 prefix_table

Get or set the prefix for table name for use Circa with more than one
time on a same database

=cut

sub prefix_table
	{
	my $self = shift;
	if (@_) {$self->{PREFIX_TABLE}=shift;}
	return $self->{PREFIX_TABLE};		
	}

=head2 connect_mysql($user,$password,$db,$server)

 $user     : Utilisateur MySQL
 $password : Mot de passe MySQL
 $db       : Database MySQL
 $server   : Adr IP du serveur MySQL

Connecte l'application à MySQL. Retourne 1 si succes, 0 sinon

=cut

sub connect_mysql
	{
	my ($this,$user,$password,$db,$server)=@_;
	my $driver = "DBI:mysql:database=$db;host=$server;port=".$this->port_mysql;
	$this->{DBH} = DBI->connect($driver,$user,$password,{ PrintError => 0 }) || return 0;
	return 1;
	}

sub close_connect {$_[0]->{DBH}->disconnect;}

=head1 Methodes administration globales

=head2 addSite($url,$email,$titre);

Ajoute le site d'url $url, responsable d'adresse mail $email à la bd de Circa

=cut

sub addSite 
	{
	my ($self,$url,$email,$titre)=@_;
	my $sth = $self->{DBH}->prepare("insert into ".$self->prefix_table."responsable(email,titre) values('$email','$titre')");
	$sth->execute;
	$sth->finish;
	$self->create_table_circa_id($sth->{'mysql_insertid'});
	$self->add_site($url,$sth->{'mysql_insertid'});
	}

=head2 addLocalSite($url,$email,$titre,$local_url,$path,$urlRacine);

Ajoute le site d'url $url, responsable d'adresse mail $email à la bd de Circa

=cut

sub addLocalSite 
	{
	my ($self,$url,$email,$titre,$local_url,$path,$urlRacine)=@_;
	my $sth = $self->{DBH}->prepare("insert into ".$self->prefix_table."responsable(email,titre) values('$email','$titre')");
	$sth->execute;
	$sth->finish;
	my $id = $sth->{'mysql_insertid'};
	$self->{DBH}->do("insert into ".$self->prefix_table."local_url values($id,'$urlRacine','$path');");
	$self->create_table_circa_id($sth->{'mysql_insertid'});	
	$self->add_site($url,$id,$local_url) || print "Erreur: $DBI::errstr<br>\n";
	}

=head2 parse_new_url($idp)

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
	my $requete="select id,url from ".$self->prefix_table.$idp."links where parse='0' and local_url is null order by id";
	my $sth = $self->{DBH}->prepare($requete);
	$self->set_agent;
	if ($sth->execute())
		{
		while (my ($id,$url)=$sth->fetchrow_array)
			{
			my ($res,$nbw,$nbwg) = $self->look_at($url,$id,$idp,undef,undef);
			if ($res==-1) {$self->{DBH}->do("delete from ".$self->prefix_table.$idp."links where id=$id");}
			else {$nbAjout+=$res;$nbWords+=$nbw;$nb++;$nbWordsGood+=$nbwg;}
			}
		}
	else {print "\nYou must call this->create_table_circa before calling this method.\n";}
	$sth->finish;
	$requete="select id,url,local_url from ".$self->prefix_table.$idp."links where parse='0' and local_url is not null order by id";
	$sth = $self->{DBH}->prepare($requete);
	$self->set_agent('local');
	if ($sth->execute())
		{
		while (my ($id,$url,$local_url)=$sth->fetchrow_array)
			{
			my ($res,$nbw,$nbwg) = $self->look_at($url,$id,$idp,undef,$local_url);
			if ($res==-1) {$self->{DBH}->do("delete from ".$self->prefix_table.$idp."links where id=$id");}
			else {$nbAjout+=$res;$nbWords+=$nbw;$nb++;$nbWordsGood+=$nbwg;}
			}
		}
	else {print "\nYou must call this->create_table_circa before calling this method.\n";}
	$sth->finish;

	return ($nb,$nbAjout,$nbWords,$nbWordsGood);
	}

=head2 update($xj,$idp)

Reindexe les sites qui n'ont pas été mis à jour depuis plus de $xj jours

=cut

sub update
	{
	my ($this,$xj,$idp)=@_;
	$this->set_agent;
	my ($nb,$nbAjout,$nbWords,$nbWordsGood)=(0,0,0,0);
	my $requete="select id,url,UNIX_TIMESTAMP(last_update) from ".$this->prefix_table.$idp."links where TO_DAYS(NOW()) >= (TO_DAYS(last_check) + $xj) and local_url is null order by url";
	my $sth = $this->{DBH}->prepare($requete);
	if ($sth->execute())
		{
		while (my ($id,$url,$last_update)=$sth->fetchrow_array)
			{
			my ($res,$nbw,$nbwg) = $this->look_at($url,$id,$idp,$last_update,undef);
			if ($res==-1) {$this->{DBH}->do("delete from ".$this->prefix_table.$idp."links where id=$id");}
			else {$nbAjout+=$res;$nbWords+=$nbw;$nb++;$nbWordsGood+=$nbwg;}
			}
		}
	else {print "\nYou must call this->create_table_circa before calling this method.\n";}
	$sth->finish;	
	$requete="select id,url,UNIX_TIMESTAMP(last_update),local_url from ".$this->prefix_table.$idp."links where TO_DAYS(NOW()) >= (TO_DAYS(last_check) + $xj) and local_url is not null order by url";
	$sth = $this->{DBH}->prepare($requete);
	if ($sth->execute())
		{
		while (my ($id,$url,$last_update,$local_url)=$sth->fetchrow_array)
			{
			my ($res,$nbw,$nbwg) = $this->look_at($url,$id,$idp,$last_update,$local_url);
			if ($res==-1) {$this->{DBH}->do("delete from ".$this->prefix_table.$idp."links where id=$id");}
			else {$nbAjout+=$res;$nbWords+=$nbw;$nb++;$nbWordsGood+=$nbwg;}
			}
		}
	else {print "\nYou must call this->create_table_circa before calling this method.\n";}
	$sth->finish;
	return ($nb,$nbAjout,$nbWords,$nbWordsGood);
	}

=head2 create_table_circa

Cree la liste des tables necessaires à Circa:

  - categorie   : Catégories de sites
  - links       : Liste d'url
  - responsable : Lien vers personne responsable de chaque lien
  - relations   : Liste des mots / id site indexes
  - inscription : Inscriptions temporaires

=cut

sub create_table_circa
	{
	my $self = shift;
	my $requete="
CREATE TABLE ".$self->prefix_table."responsable (
   id 		int(11) DEFAULT '0' NOT NULL auto_increment,
   email	char(25) NOT NULL,
   titre	char(50) NOT NULL,
   PRIMARY KEY (id)   
)";

	$self->{DBH}->do($requete) || print $DBI::errstr,"<br>\n";
	$requete="
CREATE TABLE ".$self->prefix_table."inscription (
   email	char(25) NOT NULL,
   url 		varchar(255) NOT NULL,
   titre	char(50) NOT NULL,
   dateins	date
)";
	$self->{DBH}->do($requete) || print $DBI::errstr,"<br>\n";

	$requete="
CREATE TABLE ".$self->prefix_table."local_url (
   id	int(11)     NOT NULL,
   path	varchar(255) NOT NULL,
   url	varchar(255) NOT NULL
)";
	$self->{DBH}->do($requete) || print $DBI::errstr,"<br>\n";
	}

=head2 drop_table_circa

Detruit les tables de Circa

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

=head2 drop_table_circa_id

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
	}

=head2 create_table_circa_id

Cree la liste des tables necessaires à Circa:

  - categorie   : Catégories de sites
  - links       : Liste d'url
  - relations   : Liste des mots / id site indexes
  - stats 	: Liste des requetes

=cut

sub create_table_circa_id
	{
	my $self = shift;
	my $id=$_[0];
	my $requete="
CREATE TABLE ".$self->prefix_table.$id."categorie (
   id 		int(11) DEFAULT '0' NOT NULL auto_increment,
   nom 		char(50) NOT NULL,
   parent 	int(11) DEFAULT '0' NOT NULL,
   PRIMARY KEY (id)
   )";
	$self->{DBH}->do($requete) || print $DBI::errstr,"<br>\n";

	$requete="
CREATE TABLE ".$self->prefix_table.$id."links (
   id 		int(11) DEFAULT '0' NOT NULL auto_increment,
   url 		varchar(255) NOT NULL,
   local_url 	varchar(255),
   titre 	tinyblob NOT NULL,
   description 	tinyblob NOT NULL,
   langue 	char(6) NOT NULL,
   valide 	tinyint(1) DEFAULT '0' NOT NULL,
   categorie 	int(11),
   last_check 	datetime DEFAULT '0000-00-00' NOT NULL,
   last_update  datetime DEFAULT '0000-00-00' NOT NULL,
   parse 	ENUM('0','1') DEFAULT '0' NOT NULL,
   PRIMARY KEY (id),
   KEY id (id),
   UNIQUE id_2 (id),
   KEY id_3 (id),
   KEY url (url),
   UNIQUE url_2 (url)
)";
	$self->{DBH}->do($requete) || print $DBI::errstr,"<br>\n";

	$requete="
CREATE TABLE ".$self->prefix_table.$id."relation (
   mot 		char(30) NOT NULL,
   id_site 	int(11) DEFAULT '0' NOT NULL,
   facteur 	tinyint(4) DEFAULT '0' NOT NULL,
   KEY mot (mot)
)";	
	$self->{DBH}->do($requete) || print $DBI::errstr,"<br>\n";
	$requete="
CREATE TABLE ".$self->prefix_table.$id."stats (
   id	int(11) DEFAULT '0' NOT NULL auto_increment,
   requete varchar(255) NOT NULL,
   quand datetime NOT NULL,
   PRIMARY KEY (id)
)";
	$self->{DBH}->do($requete) || print $DBI::errstr,"<br>\n";
	}

=head1 Fonctions HTML

=head2 start_classic_html

Affiche le debut de document (<head></head>)

=cut

sub start_classic_html
	{
	return start_html(
		-'title'	=> 'Circa',
		-'author'	=> 'alian@alianwebserver.com',
		-'meta'		=> {'keywords'=>'circa,recherche,annuaire,moteur',
        	-'copyright'	=> 'copyright 1997-2000 AlianWebServer'},
		-'style'	=> {'src'=>"circa.css"},
		-'dtd'		=> '-//W3C//DTD HTML 4.0 Transitional//EN" "http://www.w3.org/TR/REC-html40/loose.dtd')."\n";
	}

=head2 get_liste_liens($id)

Rend un buffer contenant une balise select initialisée avec les données 
de la table links responsable $id

=cut

sub get_liste_liens
	{
	my $self=shift;
	my ($id) =@_;
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
	return scrolling_list(	-'name'=>'id',
               		        -'values'=>\@l,
               		        -'size'=>1,
                       		-'labels'=>\%tab);
        }

=head2 get_liste_site

Rend un buffer contenant une balise select initialisée avec les données 
de la table responsable

=cut

sub get_liste_site
	{
	my $self=shift;
	my %tab;
	my $sth = $self->{DBH}->prepare("select id,email,titre from ".$self->prefix_table."responsable");
	$sth->execute() || print &header,$DBI::errstr,"<br>\n";
	while (my @row=$sth->fetchrow_array) {$tab{$row[0]}="$row[1]/$row[2]";}	
	$sth->finish;
	my @l =sort { $tab{$a} cmp $tab{$b} } keys %tab;
	return scrolling_list(	-'name'=>'id',
               		        -'values'=>\@l,
               		        -'size'=>1,
                       		-'labels'=>\%tab);
        }

=head2 get_liste_categorie($id)

Rend un buffer contenant une balise select initialisée avec les données 
de la table categorie responsable $id

=cut

sub get_liste_categorie
	{
	my $self=shift;
	my ($id) =@_;
	my (%tab,%tab2);
	my $sth = $self->{DBH}->prepare("select id,nom,parent from ".$self->prefix_table.$id."categorie");
	$sth->execute() || print &header,$DBI::errstr,"<br>\n";	
	while (my @row=$sth->fetchrow_array) {$tab2{$row[0]}[0]=$row[1];$tab2{$row[0]}[1]=$row[2];}	
	$sth->finish;
	foreach my $key (keys (%tab2)) 
		{
		my ($nb)=$self->get_first("select count(*) from ".$self->prefix_table.$id."links where categorie=$key");
		$tab{$key}= getParent($key,%tab2)." ($nb)";
		}

	my @l =sort { $tab{$a} cmp $tab{$b} } keys %tab;
	return scrolling_list(	-'name'=>'id',
               		        -'values'=>\@l,
               		        -'size'=>1,
                       		-'labels'=>\%tab);
        }

=head2 fill_template($masque,$vars)

 $masque : Chemin du template
 $vars : reference du hash des noms/valeurs à substituer dans le template

Rend le template avec ses variables substituées.
Ex: si $$vars{age}=12, et que le fichier $masque contient la chaine:

  J'ai <? $age ?> ans, 

la fonction rendra

  J'ai 12 ans,

=cut

sub fill_template
	{
	my ($self,$masque,$vars)=@_;
	open(FILE,$masque) || die "Can't read $masque<br>";
	my @buf=<FILE>;
	close(FILE);
	while (my ($n,$v)=each(%$vars)) {if ($v) {map {s/<\? \$$n \?>/$v/gm} @buf;}}	
	return join('',@buf);
	}

=head1 Methode administration par compte

=head2 admin_compte($compte)

Retourne une liste d'elements se rapportant au compte $compte:

 $responsable	: Adresse mail du responsable
 $titre		: Titre du site pour ce compte
 $nb_page	: Nombre de page pour ce site
 $nb_words      : Nombre de mots indexés
 $last_index	: Date de la dernière indexation
 $nb_requetes	: Nombre de requetes effectuées sur ce site
 $racine	: 1ere page inscrite

=cut

sub admin_compte
	{
	my ($self,$compte)=@_;
	my ($responsable,$titre) = $self->get_first("select email,titre from ".$self->prefix_table."responsable where id=$compte");
	my ($racine) 		 = $self->get_first("select min(id) from ".$self->prefix_table.$compte."links");
	($racine) 		 = $self->get_first("select url from ".$self->prefix_table.$compte."links where id=$racine");
	my ($nb_page) 		 = $self->get_first("select count(*) from ".$self->prefix_table.$compte."links");
	my ($last_index)	 = $self->get_first("select max(last_check) from ".$self->prefix_table.$compte."links");
	my ($nb_requetes) 	 = $self->get_first("select count(*) from ".$self->prefix_table.$compte."stats");
	my ($nb_words) 		 = $self->get_first("select count(*) from ".$self->prefix_table.$compte."relation");
	return ($responsable,$titre,$nb_page,$nb_words,$last_index,$nb_requetes,$racine);
	}

=head2 most_popular_word($max,$id)

Retourne la reference vers un hash representant la liste 
des $max mots les plus présents dans la base de reponsable $id

=cut

sub most_popular_word
	{
	my $self = shift;
	my %l;
	my $requete = "select mot,count(*) from ".$self->prefix_table.$_[1]."relation r group by r.mot order by 2 desc limit 0,$_[0]";
	my $sth = $self->{DBH}->prepare($requete);	
	$sth->execute;
	while (my ($word,$nb)=$sth->fetchrow_array) {$l{$word}=$nb;}
	$sth->finish;
	return \%l;
	}

=head2 delete_url($compte,$id_url)

Supprime le lien $id_url de la table $compte/relation et $compte/links

=cut

sub delete_url
	{
	my ($this,$compte,$id_url)=@_;
	$this->{DBH}->do("delete from ".$this->prefix_table.$compte."relation where id_site = $id_url");
	$this->{DBH}->do("delete from ".$this->prefix_table.$compte."links where id = $id_url");
	}

=head2 delete_categorie($compte,$id)

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

=head2 rename_categorie($compte,$id,$nom)

Renomme la categorie $id pour le compte de responsable $compte en $nom

=cut

sub rename_categorie
	{
	my ($this,$compte,$id,$nom)=@_;
	$this->{DBH}->do("update ".$this->prefix_table.$compte."categorie set nom='$nom' where id = $id")|| print "Erreur:$DBI::errstr<br>\n";
	}

=head2 inscription($email,$url,$titre)

Inscrit un site dans une table temporaire

=cut

sub inscription {$_[0]->do("insert into ".$_[0]->prefix_table."inscription values ('$_[1]','$_[2]','$_[3]',CURRENT_DATE)");}

=head1 Méthodes privées

=head2 look_at ($url,$idc,$idr,$lastModif,$url_local)

Ajoute les liens definis à l'URL $url à la base de donnée.
Indexe les mots de chaque page

 $url : Url de la page à indexer
 $idc : Id de l'url dans la table links
 $idr : Id du responsable de cette url
 $lastModif : Ne parse pas la page si elle n'a pas été mis à jour 
              depuis cette date (facultatif)
 $url_local : Chemin local pour accéder au fichier (facultatif)

Retourne (-1,0) si l'adresse est invalide, le nombre de liens trouvés dans la page ainsi
que le nombre de mots trouves sinon.

=cut

sub look_at
	{
	my($this,$url,$idc,$idr,$lastModif,$url_local) = @_;
	my ($l,$url_orig,$racineFile,$racineUrl,$lastUpdate);
	if ($url_local) 
		{
		$temporate=0;
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
	$this->set_host_indexed($url);
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
			my $categorie = $this->get_categorie($url,$idr);
			my $requete ="
				update 	".$this->prefix_table.$idr."links 
				set 	parse		= '1',
					titre		= '$titre',
					description	= '$desc',
					last_update	= '$lastUpdate',
					last_check	= CURRENT_TIMESTAMP,
					langue		= '$language',
					categorie	= $categorie
				where id=$idc";
			$this->{DBH}->do($requete) || print "Erreur $requete:$DBI::errstr<br>\n";

			# html2txt
			my $text = $res->content;
			$text=~s{ <! (.*?) (--.*?--\s*)+(.*?)> } {if ($1 || $3) {"<!$1 $3>";} }gesx; 
			$text=~s{ <(?: [^>'"] * | ".*?" | '.*?' ) + > }{}gsx;
			$text=decode_entities($text); 

			# Traitement des mots trouves
			$l = analyse_data($keyword,	$ConfigMoteur{'facteur_keyword'},	%$l);
			$l = analyse_data($desc,   	$ConfigMoteur{'facteur_description'},	%$l);
			$l = analyse_data($titre,  	$ConfigMoteur{'facteur_titre'},		%$l);
			$l = analyse_data($text,	$ConfigMoteur{'facteur_full_text'},	%$l);
			$this->{DBH}->do("delete from ".$this->prefix_table.$idr."relation where id_site = $idc");
		
			# Chaque mot trouve plus de $ConfigMoteur{'nb_min_mots'} fois 
			# est enregistre
			while (my ($mot,$nb)=each(%$l)) 
				{		
				my $requete = "insert into ".$this->prefix_table.$idr."relation (mot,id_site,facteur) values ('$mot',$idc,$nb)";
				if ($nb >=$ConfigMoteur{'nb_min_mots'}) {$this->{DBH}->do($requete);$nbwg++;}
				}
			my $nbw=keys %$l;undef(%$l);
			
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
					$this->add_site($urlb,$idr,$$var[2]) && $nburl++;
					}
				elsif ($$var[2]) {$this->add_site($$var[2],$idr);$nburl++;}
				}			
			return ($nburl,$nbw,$nbwg);
			}
		elsif ($res->content_length>$this->size_max) {print "Fichier trop grand:",ceil($res->content_length/1000000)," Mo<br>\n";}
		else {print "Aucune modification depuis la dernière indexation sur $url<br>\n";return (0,0,0);}
  		}
	# Sinon previent que URL defectueuse
	else {print "Url non valide:$url\n";return (-1,0,0);} 	
	}

=head2 add_site($url,$idMan)

Ajoute un site à la table links. 

 $url   : Url de la page à ajouter
 $idMan : Id dans la table responsable du responsable de ce site

=cut

sub add_site 
	{
	my ($self,$url,$idMan,$local_url)=@_;	
	if ($local_url) 
		{
		$self->{DBH}->do("insert into ".$self->prefix_table.$idMan."links(url,titre,description,local_url)
					 values ('$url',' ',' ','$local_url')") || return 0;
		}
	else 
		{
		$self->{DBH}->do("insert into ".$self->prefix_table.$idMan."links(url,titre,description) 
					 values ('$url',' ',' ')") || return 0;
		}
	return 1;
	}

=head2 drop_site($id)

Supprime un site de la table personne. Cela
supprime egalement les elements de la table links et relation
qui appartiennent à ce site

 $id   : Id du site

=cut

sub drop_site 
	{
	my ($self,$id)=@_;
	$self->drop_table_circa_id($id);
	$self->{DBH}->do("delete from ".$self->prefix_table."responsable where id=$id");	
	return 1;
	}

=head2 get_meta($entete)

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

=head2 analyse_data($data,$facteur,%l)

Recupere chaque mot du buffer $data et lui attribue une frequence d'apparition.
Les resultats sont ranges dans le tableau associatif passé en paramètre.
Les résultats sont rangés sous la forme %l=('mots'=>facteur).

 $data : buffer à analyser
 $facteur : facteur à attribuer à chacun des mots trouvés
 %l : Tableau associatif où est rangé le résultat

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
		$data=~tr/.;:,?!()"'[]#=/ /;	
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

=head2 getParent($id,%tab)

Rend la chaine correspondante à la catégorie $id avec ses rubriques parentes

=cut

sub getParent
	{
	my ($id,%tab)=@_;	
	my $parent;
	if (($tab{$id}[1]!=0)&&($tab{$id}[0])) {$parent = &getParent($tab{$id}[1],%tab);}	
	if (!$tab{$id}[0]) {$tab{$id}[0]='Home';}
	$parent.=">$tab{$id}[0]";
	return $parent;
	}

sub get_categorie
	{
	my ($self,$rep,$responsable) = @_;
	my $ori = $self->host_indexed;
	$rep=~s/$ori//g;
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

sub check_links 
	{
     	my($self,$tag,$links) = @_;
     	my $host = $self->host_indexed;
     	my $bad = qr/\.(doc|zip|ps|gif|jpg|gz|pdf|eps|png|deb|xls|ppt|class|GIF|css|js|wav)$/i;
	if (($tag) && ($links) && ($tag eq 'a') && ($links=~/^$host/) && ($links !~ $bad)) 
		{
		if ($links=~/^(.*?)#/) {$links=$1;} # Don't add anchor
		if ((!$indexCgi)&&($links=~/^(.*?)\?/)) {$links=$1;}		
		return $links;		
		}
	return 0;
 	}
 
=head2 get_first($requete)

Retourne la premiere ligne du resultat de la requete $requete sous la forme d'un tableau

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
