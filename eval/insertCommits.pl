#!/usr/bin/perl


$0 =~ m@/([^/]+)$@;
my $xxdir = $`; #'

push @INC, $xxdir ;

# this program inserts the metadata of commits


use strict;
use POSIX 'strftime';
use Digest::SHA  qw(sha1 sha1_hex sha1_base64);


###
# logRepo.pl

# first we need to find the branches that are here...

# then we have to checkout each of them

# we start with the assumption we are in a gip repo

# get branches

use strict;
use DBI;

my $dryRun = 0;


# find the last-modified for the pack files directory
# which is the most reliable way to know when the files were last changed
# i think...

my $dbName = $ARGV[0];
my $repoDir = $ARGV[1];
my $parm = $ARGV[2];

my @temp = split(',', $parm);
my %options;

foreach my $a (@temp) {
    $options{$a} = $a;
}

die "usage $0 <db> <repoDirectory> <force?>"  unless -d $repoDir ;

die "$repoDir not a git repo"  unless -d "$repoDir/.git" ;


my $userName = 'dmg';

my $dbh = DBI->connect("dbi:Pg:dbname=$dbName", "$userName", "",
		       { RaiseError => 1,
                         AutoCommit => 0});

my $temp = $dbh->prepare("set client_encoding to latin1");
$temp->execute();

my $create = $dbh->prepare("
CREATE TABLE commits (
    cid character(40),
    author character varying(200),
    committer character varying(200),
    ismerge boolean,
    contents character(40),
    autdatereal timestamp with time zone,
    comdatereal timestamp with time zone,
    codecontents character(40),
    reporeal character varying(80)
);
");
$create->execute();

$create = $dbh->prepare("
CREATE TABLE parents (
    cid character(40),
    index integer,
    parent character(40)
);
");
$create->execute();

my $insC = $dbh->prepare("insert into commits(author, autdatereal, committer, comdatereal, ismerge, contents, cid) values (?, ?,?,?,?,?,?);");
my $insP = $dbh->prepare("insert into parents(cid, index, parent) values (?, ?, ?);");

#----------------------------------------------------------------------

# first read all the commits that we need that are missing

open(IN, "git -C $repoDir log  --pretty=fuller --parents |") or die "unable to execute git";

my %fields;
my $cid;
my $inBody; #flag to decide when to ignore data in the log
my $contents = "";
#we implement a simple FSM that starts when a '^commit' is seen. 
#if we are in another state, we update the commit we are currently looking at

my $doneUp = 0;

my $i;
while (<IN>) {
    my $o = $_;
    chomp;
    if (/^commit ([a-f0-9]{40})/) {
        $i++;
        if ($i % 1000==0) {
            print STDERR "$i\n";
        }
        #we need to flush what we have
        if ($cid ne "") {
            # remove the last end of line.. it is not part of the contents.. it is a separator
            $contents = substr($contents, 0, -1);
            # ok, now we have to deal with the commit.
            $fields{shaContent} = sha1_hex($contents);
            $fields{cid} = $cid;
            Insert_Commit($cid, $contents, %fields);
            $doneUp ++;
            
        } 

        # go to beginning of FSM
        $inBody = 0;
        $cid = $1;
        my @parents;
        @parents = split(' ', substr($_, 47));
        Insert_Parents($cid, @parents);

        $contents = "";
        %fields = ();
    } elsif ($inBody) {
        $contents .=  $o;
    } elsif ($_ eq "") {
        $inBody = 1;
    } else {
        die "[$_] cid [$cid]" unless /^([A-Za-z]+):\s+(.+)$/;
        $fields{$1} = $2;
    } 
}
# flush the last one
# remove the last end of line.. it is not part of the contents.. it is a separator
$contents = substr($contents, 0, -1);
# ok, now we have to deal with the commit.
$fields{shaContent} = sha1_hex($contents);
$fields{cid} = $cid;
Insert_Commit($cid, $contents, %fields);
$i++;

print "Insert [$i] commits\n";

close IN;

$dbh->commit();

$dbh->disconnect();

exit(0);

sub Insert_Commit
{
  my (%fields) = @_;
  my $merge =0;
  if (defined($fields{Merge})) {
      $merge = 1;
  } else {
      $merge = 0;
  }
  die "error empty [$fields{cid}]" if $fields{cid} eq "";
  print "To insert [$fields{cid}]\n";

 $insC->execute($fields{Author}, 
               $fields{AuthorDate},
               $fields{Commit},
               $fields{CommitDate},
               $merge,
               $fields{shaContent},
               $fields{cid}
              ) unless $dryRun;
}



sub Insert_Parents
{
  my ($cid, @parents) = @_;

  my $i =0;
  foreach my $p (@parents) {
    $insP->execute($cid, $i, $p);
    print "Inserting parent [$cid][$i][$p]\n";
    $i++;
  }
}

sub Process_Diff
{
    my ($fileN) = @_;
    my $line;
    my %fields;
    open(IN, "<$fileN") or die "Unable to open [$fileN]";

    my ($commitInfo,@parents) = Parse_Commit_Line();
    $fields{cid} = $commitInfo;
    while ($line =  <IN>) {
        chomp $line;
        last if $line eq "";
        my ($key, $value) = Parse_Line($line);
#        print "[$key][$value]\n";
        $fields{$key} = $value;
    }
    my $content  = "";
    while ($line = <IN>) {
        $content .= $line;
    }
    $fields{content} = $content;
    $fields{shaContent} = sha1_hex($content);
    close(IN);
    $fields{parents} = [@parents];
    return %fields;
}

sub Parse_Commit_Line
{
    my $line  = <IN>;
    chomp $line;
    die "File does not have commit line [$line]" unless $line =~ /^commit\s+(.+)/;
    return split(' ', $1);
}

sub Parse_Line
{
    my ($line) = @_;
    
    die "File does not proper field [$line]" unless $line =~ /^([^:]+):\s+(.+)/;
    return ($1,$2);
}



chdir($repoDir);


