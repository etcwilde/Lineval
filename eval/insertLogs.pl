#!/usr/bin/perl


$0 =~ m@/([^/]+)$@;
my $xxdir = $`; #'

push @INC, $xxdir ;

# this program inserts the metadata of commits


use strict;
use POSIX 'strftime';
use Digest::SHA  qw(sha1 sha1_hex sha1_base64);
use DBI;

my $dbName = $ARGV[0];
my $repoDir = $ARGV[1];
my $userName = "dmg";

die "usage $0 <db> <repoDirectory> <force?>"  unless -d $repoDir ;

die "$repoDir not a git repo"  unless -d "$repoDir/.git" ;

my $dbh = DBI->connect("dbi:Pg:dbname=$dbName", "$userName", "",
		       { RaiseError => 1, AutoCommit=>0});

my $create = $dbh->prepare("drop table logs;");
        
$create->execute();

my $create = $dbh->prepare("CREATE TABLE logs (
    cid character(40) NOT NULL,
    log character varying(10000),
    primary key (cid)
);");
$create->execute();

my $ins = $dbh->prepare("insert into logs(cid, log) values (?, ?); ");

open(IN, "git -C $repoDir log  --pretty=oneline |");

my $i =0;
while(<IN>) {
    chomp;
    my $cid = substr($_, 0,40);
    my $log = substr($_, 41);
    $ins->execute($cid, $log);
    if ($i++ % 10000 == 0) {
        print STDERR "$cid;[$log]\n";
        print STDERR "$i\n";
    }
}
print "Done $i commits\n";

close(IN);

$dbh->commit();
exit (0);
