#!/usr/bin/perl

use DBI;

# 
# Compare the merges  with the logs

$0 =~ m@/([^/]+)$@;
my $xxdir = $`; #'

push @INC, $xxdir ;

use strict;

my $dryRun = 0;
my %byLinus;

my $dbName = shift @ARGV;
my $repoDir = shift @ARGV;
my $userName = "dmg";

my $usage = "$0 <dbName> <repo>\n";

die ("no database provided [$dbName] \n" . $usage)  if $dbName eq "";
die ("not a git repo [$repoDir]\n" . $usage) if not -d "$repoDir/.git";


my $dbh = DBI->connect("dbi:Pg:dbname=$dbName", "$userName", "",
		       { RaiseError => 1, AutoCommit=>0});
my $del = $dbh->prepare("delete from  integrations;");
$del->execute();

my $ins = $dbh->prepare("insert into integrations(mcidlinus, mcount) values (?,?);");

# this one takes a log create with git log --author='Torvalds' 
# the idea is to compare how accurate we are in the commits that
# are merged at any given point by linus.

my $cid = '';
my $isMerge = 0;
my $haveToCount = 0;
my @count = ();
my $i;
my $date = '';
my $save = '';




open(IN, "git -C $repoDir log --merges --author='Torvalds' |") or die "unable to execute git";

while (<IN>) {
conti:
    $save .= $_;
    chomp;
#    print "Input :$_\n";
    if (/^commit ([0-9a-f]{40})$/) {
	$i = 0;
	if ($cid and $isMerge) {
	    foreach my $j (@count)  {
		$i+= $j;
	    }
	    my $x  = ` perl commitsAtMerge.pl $dbName merges $cid`;
	    chomp $x;

	    my ($skip, $dbCid, $dbCount) = split(';', $x);
	    if ($cid ne $dbCid) {
		print STDERR "unable to find commits at merge [$cid][$x]-[$dbCid][$dbCount]\n" ;
		while (<>) {
		    chomp;
		    last if /^commit/ or $_ eq "";
		}
	    }
	    if ($dbCount == $i) {
		print "Match [$cid][$date][$i]\n";
		$ins->execute($cid, $i) if not $dryRun;
	    } else {
		print "No match [$cid][$date][$i][$dbCount]\n";
		print "cid [$cid][$date] count log [$i] dbcount [$dbCount].... NO Match :(\n";
		print STDERR "cid [$cid][$date] count log [$i] dbcount [$dbCount].... NO Match :(\n";
		foreach my $j (@count)  {
		    print "   values of regions [$j]\n";
		}
		print $save;
		$x  = ` perl commitsAtMerge.pl $dbName merges $cid logs`;
		print "\n----------\n$x\n----------\n";
		print STDERR $save;
		print STDERR "\n----------\n$x\n----------\n";
	    }
	}
	$isMerge = 0;
	$haveToCount =0;
	$date = '';
	$i = 0;
	$cid = $1;
	$save = "";
	@count = ();
    } elsif (/^Date:/) {
	$date = $_;
    } elsif (/^Merge:/) {
#	print "new commit [$cid]\n";
	$isMerge = 1;
    } elsif ($isMerge and /^    \* .+: \((\d+) (commits|patches)\)$/) {
#	print "Number of commts in merge [$cid][$1]\n";
	push(@count, $1);
    } elsif ($isMerge and /^    \* .+:$/) {
	$haveToCount =1;
    } elsif ($haveToCount and /^(|    )$/) {
	$haveToCount = 0;
#	print "Number of commts counted in merge [$cid][$i]\n";
	push(@count, $i);
	$i = 0;
    } elsif ($haveToCount) {
	$i++;
    } else {
    }
}

if ($cid and $isMerge) {
    foreach my $j (@count)  {
	$i+= $j;
    }
    print "cid [$cid] count [$i]\n";
}

$dbh->commit();
$dbh->disconnect();
exit(0);

sub Get_Linus_Merges
{
    my $i;

    my $q = $dbh->prepare("select mcidlinus from closest;");
    print STDERR "Reading merges by linus\n";
    $q->execute();
    while (my ($cid,$ismerge,$comdate, $d, $whenMerged) =  $q->fetchrow_array()) {
        $byLinus{$cid} = $cid;
        $i++;
    }
    print STDERR "End Reading merges by linus [$i]\n";
}
