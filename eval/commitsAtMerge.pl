#!/usr/bin/perl

# This one dumps the commits that are merged at a given commit 
# basically the tree backwards

$0 =~ m@/([^/]+)$@;
my $xxdir = $`; #'

push @INC, $xxdir ;

use POSIX 'strftime';


use strict;
use DBI;




my $dbName = $ARGV[0];
my $distanceType = $ARGV[1];
my $cid = $ARGV[2];
my $parm = $ARGV[3];


my @temp = split(',', $parm);
my %options;


foreach my $a (@temp) {
    $options{$a} = $a;
}


my %savedDistance; # saved the distance to linus, so we don't have to query it again
my %unmerged; # commits that have not been merged yet

my %savedIsMerge;
my %savedFirstParent;

my $userName = 'dmg';

die "usage $0 <db>  <merges|time> <cid> <force|init|print>"  if $dbName eq "" or not ($distanceType eq "merges" or $distanceType eq "time");

die "not implemented" if $distanceType ne 'merges';

my $dbh = DBI->connect("dbi:Pg:dbname=$dbName", "$userName", "",
		       { RaiseError => 1});

my $merge = $dbh->prepare("select ismerge from commits where cid = ?;");

#print "New: $cid\n";
my $is = Simple_Query("select mcidlinus from closest where mcidlinus = ?", $cid);
if ($is ne $cid) {
    print "Total;$cid;-1\n";
    exit(0);
}

my @t = Simple_Query("select ismerge,comdate,committer,autdate,author,'' as rip,log from commits c natural join logs  where c.cid = ?", $cid);
my $c = Print_Commit($cid, 0, 0, @t);
print "Total;$cid;$c\n";

sub Print_Commit
{
    my ($cid, $indent, $distance, @info) = @_;
    
    print " " x $indent, "$cid;$distance;", join(';', @info), "\n" if $options{"print"};
    print " " x $indent, "",  $info[6], "\n" if $options{"logs"};
    
    # find its predecessors

    my $q = $dbh->prepare("select cid,mdist, 'repo',ismerge,comdate,committer,autdate,author, log from closest natural join commits natural join logs where mnext = ? order by mdist desc;");
    
    $q->execute($cid);

    my $c = 1;

    if (Is_Merge($cid)) {
        $c--;
    }

    my $thisC = 0;
    while (my @data = $q->fetchrow_array()) {
	if (not defined ($data[2])) {
	    $data[2] = $data[3];
	}
	$data[3] = "";
        my ($thisCid, $thisDistance,@rest) = @data;
        if ($thisDistance == 0) {
            ; # we dont'  print it because it is in linus tree already
        } elsif ($thisDistance == $distance) {
	    my $d = Print_Commit($thisCid, $indent, $thisDistance, @rest);
#	    print "This $thisCid merged [$d]\n";
            $c += $d;
        } elsif ($thisDistance == $distance + 1) {
            my $d = Print_Commit($thisCid, $indent + 3, $thisDistance, @rest);
	    $thisC += $d;
            $c += $d;
        } else {
            print STDERR "illegal distance this distance [$cid]thiscid [$thisCid]this distance [$thisDistance] distance [$distance]\n";
	    exit 0;
        }
    }
#    print STDERR "> [$cid] merged down [$thisC]\n" if $thisC > 0;

    return $c;

}


sub Is_Merge($)
{
  my ($cid) = @_;

  my @result;
  $merge->execute($cid);
#  print "Is merge [$cid]\n";
  while (my @data =  $merge->fetchrow_array()) {
    push @result, $data[0];
  }
  die "this query should always return only one row [Is merge][$cid]" . join(":", @result)  unless scalar(@result) <= 1;
#  print "is merge [$cid] is [$result[0]]\n";

  return $result[0];
}



sub Simple_Query
{
    my ($query, @parms) = @_;
    my $q = $dbh->prepare($query);
    $q->execute(@parms);
    return $q->fetchrow_array();

}

