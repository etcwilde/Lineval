#!/usr/bin/perl

###
#
#drop table closest; create table closest (cid char(40), mnext char(40), mdist integer, mwhen timestamp,  tnext char(40), tdist interval, twhen timestamp); 
#gitlinux=# \d closest
#                Table "public.closest"
#   Column   |            Type             | Modifiers 
#------------+-----------------------------+-----------
# cid        | character(40)               | not null
# mnext      | character(40)               | 
# mdist      | integer                     | 
# mwhen      | timestamp without time zone | 
# mnextmerge | character(40)               | 
# mcidlinus  | character(40)               | 
#Indexes:
#    "closest_pkey" PRIMARY KEY, btree (cid)
#    "closestmnext" btree (mnext)
#
##
##

sub Find_Children($);
sub Follow_The_Rabbit($$);
sub Distance($$);
sub Set_Distance($$$$$$$);
sub Find_Children($);
sub Find_Parents($);
sub Find_First_Parent($);
sub Is_Merge($);
sub Get_Commit_Date($);

my $verbose = 1;

####################################################33

my $rip = '5c2a5ce689c99037771a6c110374461781a6f042';

my $tableClosest = "closest";
my $tableParents = "parents";

$0 =~ m@/([^/]+)$@;
my $xxdir = $`; #'

push @INC, $xxdir ;

use POSIX 'strftime';
#require 'gitCommon.pm';

use strict;
use DBI;

# latest commit 
# 2145199c4f0db7c517dd788abec301dc84b91bd0',

#my %headCommit = (
#    "gitlinux" => '2d534926205db9ffce4bbbde67cb9b2cee4b835c', # just before aug1, 2012
#    "gitlinux" => '4a490b78cb7e0e5efa44425df72a9fedc1c36366', # just before end of 2012
#    "gitlinux" =>  '722aacb28588c7d0326493d1a0700d6a886be7b9', # april 10, 2013
#    'gitlinux' => 'bf81710c4b6e2df2cc047f7c8e1f342511904b74',
#    "gitlinux" =>  'd9a5c0a4e0b4c84850a1a5bbacba3f7858b67037', # March 24, 2007
#    );

#7f80850d3f9fd8fda23a317044aef3a6bafab06b',

my $dbName = $ARGV[0];
my $distanceType = $ARGV[1];
my $parm = $ARGV[2];

my @temp = split(',', $parm);
my %options;


foreach my $a (@temp) {
    $options{$a} = $a;
}

my %savedDistance; # saved the distance to linus, so we don't have to query it again
my %savedWhen;     # saved when it was merged
my %savedNextMerge;  # save the next merge of the commit towards linus, nil if in linus trunk
my %savedLinusMerge; # save the merge in linus trunk


my %savedCommitDate; # save the date a commit was committed

my %unmerged; # commits that have not been merged yet

my %savedIsMerge;
my %savedFirstParent;
my %savedSecondParent;
my $userName = 'dmg';

die "usage $0 <db> <merges|time> <force|init|check>"  if $dbName eq "" or not ($distanceType eq "merges");



my $dbh = DBI->connect("dbi:Pg:dbname=$dbName", "$userName", "",
		       { RaiseError => 1, AutoCommit=>0});

#$dbh->{AutoCommit} = 0; 

my $headCommit = Simple_Query("select cid from commits except select parent from parents");



my $parentsQ = $dbh->prepare("select parent from $tableParents where cid = ?;");
my $childQ = $dbh->prepare("select cid from $tableParents where parent = ?;");
my $firstParentQ = $dbh->prepare("select parent from $tableParents where cid = ? and index = 0;");
my $secondParentQ = $dbh->prepare("select parent from $tableParents where cid = ? and index = 1;");

my $sth;


# before we do anything... let us make sure that the data is good

# no commit in baseline should have empty metadata: author, realcomdate
# all commits in baseline should have a realrepo

print "Options: ", join (';', sort keys %options), "\n";

if (not defined ($options{"nocheck"})) {
    print "Checking if there are any null values in commits JOIN baseline\n";
    my ($checkMetadata) = Simple_Query("select count(*) from commits natural join baseline where comdatereal is null or committer is null");
    
    die "number null [$checkMetadata]"  if $checkMetadata > 0;
    
    print "Checking that there are no commits without parents in baseline except for anything that is recent\n";
    
    my ($orphans) = Simple_Query("select count(*) from (select cid from baseline natural join commits where comdatereal > '2013-01-01' except select cid from parents) as rip");
    
    die "number of baseline orphans without a record in parents [$orphans]"  if $orphans > 1;
    
    my ($orphans) = Simple_Query("select count(*) from (select cid from baseline natural join commits where comdatereal > '2013-01-01' except select parent from parents) as rip");
    
    die "number of parents that are not a parent in closest [$orphans] only head of torvalds shouldn't"  if $orphans > 1;
    
    if ($dbName ne "evan") {
	die "It is not probably to work for other dbs than [evan]";
    }
}

# prepare all the queries

my $distField = "mdist";
my $nextField = "mnext";
my $whenField = "mwhen";

#if ($distanceType eq "time") {
#    $distField = "tdist";
#    $nextField = "tnext";
#    $whenField = "twhen";
#}

my $queryDistance = $dbh->prepare("select $distField,$whenField, mnextmerge, mcidlinus from $tableClosest where cid = ?;");

my $updateDistance  = $dbh->prepare("update $tableClosest set $nextField = ?, $distField = ?, $whenField = ?, mnextmerge = ?, mcidlinus = ? where cid = ?;");

my $merge = $dbh->prepare("select ismerge from commits where cid = ?;");
my $commitDate = $dbh->prepare("select comdatereal from commits where cid = ?;");


# insert what is not in the table yet

print "shall we insert..\n";


if (not defined ($options{"noinsert"})) {
    print STDERR "inserting not seen yet\n";
    $sth = $dbh->prepare("insert into $tableClosest(cid) select cid from commits except select cid from $tableClosest;");
    $sth->execute();
    print STDERR "end inserting not seen yet\n";
}

my %baseline;
Get_Baseline();


### first make sure that the last commit in Linus head has distance zero

my $when = Get_Commit_Date($headCommit);
Set_Distance($headCommit, "", 0, $distanceType, $when, undef, undef) if not defined($savedDistance{$headCommit});
undef($when);

# now  update every single commit that does not have a distance

my %done;
if (not defined ($options{"nomaster"})) {
    print STDERR "update master code line \n";
    Update_Master_Code_Line();
    print STDERR "End update master code line \n";
}

my @toProcess = ($headCommit);


while (my $cid = pop @toProcess) {
#  print "We are going to process [$cid]\n";

  my ($distance,$whenMerged) = Follow_The_Rabbit($cid, $distanceType);
  if (defined ($distance)) {
    # we have a distance
#    print "This commit has a distance [$cid][$distance] and was merged [$whenMerged]\n";
  } else {
    print "This commit does not have a distance [$cid]\n";
  }
  
  # now push its parents
  $done{$cid} = $cid;
  my @parents = Find_Parents($cid);
  foreach my $parent  (@parents) {
      # only push it if we have not seen it
      push (@toProcess, $parent ) if not defined $done{$parent};
  }
}

#$dbh->commit();
$dbh->commit();
$dbh->disconnect();

sub Update_Master_Code_Line
{
    my $prevDate = Get_Commit_Date($headCommit);
    my $cid = $headCommit;
    my $prev = "";
    my $i=0;
    my $total = 0;

    print "Delete the tuples that Update the ones that have been heads before\n";
    my $del = $dbh->prepare("delete from closest where cid in ( select cid from closest where mnext = '' ) and cid <> '$headCommit';");
    $del->execute();

    print "Finding commits that are in master code line\n";

    while (defined($cid)) {
#  print "We are going to process [$cid]\n";
        my $thisDate = Get_Commit_Date($cid);
        my ($distance,$whenMerged, $nextMerge, $cidMergeLinus) = Distance($cid, $distanceType);
#    print "updating master code lines $cid;$distance;", Get_Commit_Date($cid), ",$nextMerge,$cidMergeLinus\n";
        
        if (defined ($distance)) {
            # we have a distance
            die "This commit should have  a distance 0 [$cid]distance [$distance]\n" if $distance > 0;
        }  else {
            Set_Distance($cid, $prev, 0 ,$distanceType, $thisDate, undef, undef)
        }
        # now push its parents
        #print "$cid;$distance;", Get_Commit_Date($cid), "\n";
        if ($thisDate gt $prevDate) {
            print "commit $cid [$i]\n";
            $i++;
        }
        
        $prev = $cid;
        
#  my @parents = Find_Parents($cid);
        my $first = Find_First_Parent($cid);
        
	if ($dbName eq "evan") {
	    if (defined ($baseline{$first})){


		my ($thisCom,  $thisIsMerge) = Simple_Query("
                   select committer,  ismerge
                   from commits C 
                   where c.cid = '$first';
                ");

		if ($thisIsMerge) {
		    my $second = Find_Second_Parent($cid);
		    if ($second ne "") {
			my $secondCom = Simple_Query("select committer from commits where cid = '$second';");
			# in this case, the order is backwards, due to a fast forward, most likely
			if (not ($thisCom =~ /Torvalds/) and ($secondCom =~ /Torvalds/)) {
			    $first = $second;
			    print "Swap [$first][$second][$thisCom] with [$secondCom]\n";
			    ($thisCom, $thisIsMerge) = Simple_Query("
                                select committer, ismerge
                                from commits C 
                                where c.cid = '$first';
                            ");
			}
		    }
		}

#		print "->commit [$first][$thisCom] parent [$cid]\n";
		print "This commit is fastfoward in main repo [$first][$thisCom]\n" if ($thisCom =~ 'Torvalds') and $verbose;
	    }
	} else {
	    die "not implemented for others than linux";
	}

        $cid = $first;
        
        $prevDate = $thisDate;
        $total++;
    }
    print "Total number of commits in linus line [$total] fixed [$i]\n";
}
exit(0);


sub Follow_The_Rabbit($$)
{
    my ($cid, $type) = @_;
    
    die "[$type]" unless $type eq "merges";

    #first check if it has been unmerged
    if (not defined($baseline{$cid})) {
        return undef;
    }

#    print "Following the rabbit [$cid]\n";

    # check if we already know the distance to this guy
    # create a block so we can create local variables for this area only
    {
	#does this one already has a distance... 
        my ($distance,$whenMerged, $cidNextMerge, $cidLinusMerge) = Distance($cid, $type);
        
        if (defined($distance)) {
	     # then we are done
            return ($distance,$whenMerged,$cidNextMerge, $cidLinusMerge);
        }
        undef $whenMerged;
        undef $cidNextMerge;
        undef $cidLinusMerge;
    }
    #if we are here, it means we have not computed the distance for this commit
    
    my @children = Find_Children($cid);
    
    my $min;
    my $minWhenMerged;
    my $minCid;
    my $minCidMerge;
    my $minCidLinus;

    my $i = -1;
    my @masters; # not sure what this is for... but it is for debugging
                 # oh i remembered... it is the number of children that are in the
                 # master branch

    # if it has children, check them
    if (scalar(@children) > 0) {
        # check which of the children is closest
        
        foreach my $child (@children) {
            # process child 
            $i++;

            my ($childDistance,$whenMerged, $mergeNext, $mergeLinus) = Follow_The_Rabbit($child, $type);

 #           print "distance [$childDistance] was merged [$whenMerged]\n";

            if (defined($childDistance)) {
                # if we are here that means the child has been merged

                if ($childDistance == 0) {
                    push (@masters, $child);
                }

                # if we are measuring in 'hoops'
                if (Is_Merge($child)) {
                    # is the child a merge?
                    # if it is a merge, and we not the first parent of the child...
                    # then we are merging down
                    my $firstParentOfChild = Find_First_Parent($child);
                    if ($firstParentOfChild eq $cid) {
                        # we are in the same codeline
                        # distance does not change
                    } else {
                        # then we have just jumped one level down
                        # that means that the next merge is this one
                        # that means that the next merge is the child
                        $mergeNext = $child;
                        if ($childDistance == 0) {
                            # this is a merge in linus torvalds?
                            # udpate the mergelinus to be the child itself
                            $mergeLinus = $child;
                        } 
                        $childDistance++;

                    }
                }
                if (defined($min)) {
                    my $update = 0;

                    if ($cid eq $rip) {
                        print STDERR "Beging check\n";
                        print STDERR "Cur index [$i]: $cid;$child;$childDistance;$whenMerged\n";
                        print STDERR "Bes index [$i]: $cid;$minCid;$min;$minWhenMerged\n";
                    }
#                    if ($childDistance < $min) {
#                        # if the child distance is better
#                        $update = 1;
#                    } els
#$childDistance == $min and 
                    # we compare dates as strings....XXX
                    if ($whenMerged eq $minWhenMerged and
                        $childDistance < $min) {
                        $update = 1;
                    }
                    if ($whenMerged lt $minWhenMerged) {
                        # if the child is the same distance
                        # but it is merge faster
                        $update = 1;
                    } 
                    # we have a current min distance.... so compare it
                    if ($update) {
                        print STDERR "Do update\n" if ($cid eq $rip);


                        $minCid = $child;
                        $min = $childDistance;
                        $minWhenMerged = $whenMerged;
                        $minCidMerge = $mergeNext;
                        $minCidLinus = $mergeLinus;
                    }  else {
                        # otherwise we just skip it
                    }
                    if ($cid eq $rip) {
                        print STDERR "End of check\n";
                        print STDERR "Cur: $cid;$child;$childDistance;$whenMerged\n";
                        print STDERR "Bes: $cid;$minCid;$min;$minWhenMerged\n";
                    }

                } else {
                    # the min is not defined... 
                    # therefore this is better
                    if ($cid eq $rip) {
                        print STDERR "First [$i]\n";
                        print STDERR "Cur: $cid;$child;$childDistance;$whenMerged\n";
                        print STDERR "Bes: $cid;$minCid;$min;$minWhenMerged\n";
                    }

                    $minCid = $child;
                    $min = $childDistance;
                    $minWhenMerged = $whenMerged;
                    $minCidMerge = $mergeNext;
                    $minCidLinus = $mergeLinus;
                }
                print "commit [$cid] has more masters than 1 [" . scalar(@masters) . "]" if (scalar(@masters) > 1);

            } else {
                # the distance is not defined, this means it has not been merged
                # we just skip it
            }
        } #end of for loop
        # so it had children
        # there are two options. 


    } else {
        # if it does not have a children
        # and it does no have a next,
        # then it is dangling in space
    }
    if (defined($min)) {

        if ($min == 0) {
            # this is already merged so the time it is merge is itself
#            print "Commit [$cid] is already at distance zero [0] [$whenMerged]\n";
            $minWhenMerged = Get_Commit_Date($cid)
        }

        if ($cid eq $rip) {
            print STDERR "DONE\n";
            print STDERR "Bes: $cid;$minCid;$min;$minWhenMerged\n";
        }

        Set_Distance($cid, $minCid, $min, $type, $minWhenMerged, $minCidMerge, $minCidLinus);
    } else {
#        print "Commit that has not been merged yet [$cid]...\n";
        $unmerged{$cid} = $cid;
	die "this commit [$cid] should have been marged, it is in baseline" if defined($baseline{$cid});
        Set_Distance($cid, undef, -1, $type, undef, undef, undef);
    }
#    print "Returning [$cid][$min][$minWhenMerged]\n";
    return ($min,$minWhenMerged, $minCidMerge, $minCidLinus);
}

##sub Is_In_Linus_Tree
##{
##    my ($cid, $type) = @_;
##    
##    # to be in linus tree a commit should 
##    # a) distance zero, or
##    # b) it first parent have distance zero, or
##
##    # first check its distance
##
##    my $distance = Distance($cid, $type);
##    if (defined($distance)) {
##        return $distance == 0;
##    }
##    # ok, at this point we don't know its distance
##    # follow only its first parent
##
##    my $firstParent = Find_First_Child_Of_Parent($cid);
##    my $firstChild = Find_First_Child_Of_Parent($cid);
##    if (defined ($firstChild)) {
##        # we have a first parent
##        print("Finding [$cid] first parent [$firstParent] distance [$distance]\n");
##        return Is_In_Linus_Tree($firstParent,$type);
##    } else {
##        # we are the root
##        # we don't know if this is the repo
##        return 0;
##    }
##    die "it should never get here  [Is_In_Linus_Tree]";
##}


sub Distance($$)
{
  my ($cid, $type) = @_;
  my $q;
  
#  print "Reading Distance [$cid]\n";
  if ($unmerged{$cid}) {
      return (undef, undef);
  }

  # have we cached it?
  if (defined $savedDistance{$cid}) {
      return ($savedDistance{$cid}, $savedWhen{$cid}, $savedNextMerge{$cid}, $savedLinusMerge{$cid});
  }

  $q = $queryDistance;
  $q->execute($cid);
  my @data = $q->fetchrow_array();

  if (defined($data[0]) and
      $data[0] = -1) {
      $unmerged{$cid} = $cid;
      return (undef, undef);
  }

#  print "Reading Distance [$cid][$data[0]][$data[1]]\n";
  return (@data);
}

sub Set_Distance($$$$$$$)
{
  my ($cid, $next, $d, $type, $whenMerged, $nextMerge, $linusMerge)  = @_;
  
  if ($type ne "merges" and $type ne "time") {
    die "illegal type $type";
  }
  die "repeated set distance [$cid][", $savedDistance{$cid},"][$d]" if defined($savedDistance{$cid});

  print "Set Distance in DB cid [$cid] next commit [$next] distance [$d] type [$type] when [$whenMerged]\n" if defined($next);


  $updateDistance->execute($next, $d, $whenMerged, $nextMerge, $linusMerge, $cid);

  $savedDistance{$cid} = $d;
  $savedWhen{$cid} = $whenMerged;
  $savedNextMerge{$cid} = $nextMerge;
  $savedLinusMerge{$cid} = $linusMerge;
}


sub Find_Children($)
{
    my ($cid) = @_;
    my @result;
    $childQ->execute($cid);
    while (my @data = $childQ->fetchrow_array()) {
        next if not defined($baseline{$data[0]});
        push @result, $data[0];
    }
    return @result;
}

sub Find_Parents($)
{
    my ($cid) = @_;
    my @result;
    $parentsQ->execute($cid);
    while (my @data = $parentsQ->fetchrow_array()) {
        next if not defined($baseline{$data[0]});
        push @result, $data[0];
  }
  return @result;
}



sub Find_First_Parent($)
{
  my ($cid) = @_;
  if (defined $savedFirstParent{$cid}) {
      return $savedFirstParent{$cid};
  }
  my @result;
  $firstParentQ->execute($cid);
#  print "Find first parent [$cid]\n";
  while (my @data =  $firstParentQ->fetchrow_array()) {
      push @result, $data[0];
  }
  die "this query should always return only one row [Find_First_Parent][$cid]" . join(":", @result)  unless scalar(@result) <= 1;
#  print "its first parent of [$cid] is [$result[0]]\n";
  $savedFirstParent{$cid} = $result[0];
  die "this commit is not in baseline! [$cid]" unless $baseline{$cid};
  return $result[0];
}

sub Find_Second_Parent($)
{
  my ($cid) = @_;
  if (defined $savedSecondParent{$cid}) {
      return $savedSecondParent{$cid};
  }
  my @result;
  $secondParentQ->execute($cid);
#  print "Find second parent [$cid]\n";
  while (my @data =  $secondParentQ->fetchrow_array()) {
      push @result, $data[0];
  }
  die "this query should always return only one row [Find_Second_Parent][$cid]" . join(":", @result)  unless scalar(@result) <= 1;
#  print "its second parent of [$cid] is [$result[0]]\n";
  $savedSecondParent{$cid} = $result[0];
  die "this commit is not in baseline! [$cid]" unless $baseline{$cid};
  return $result[0];
}


sub Is_Merge($)
{
  my ($cid) = @_;

  if (defined($savedIsMerge{$cid})) {
      return $savedIsMerge{$cid};
  }
  my @result;
  $merge->execute($cid);
#  print "Is merge [$cid]\n";
  while (my @data =  $merge->fetchrow_array()) {
    push @result, $data[0];
  }
  die "this query should always return only one row [Is merge][$cid]" . join(":", @result)  unless scalar(@result) <= 1;
#  print "is merge [$cid] is [$result[0]]\n";

  $savedIsMerge{$cid} = $result[0];
  return $result[0];
}




sub Get_Commit_Date($)
{
  my ($cid) = @_;

  if (defined($savedCommitDate{$cid})) {
      return $savedCommitDate{$cid};
  }
  my @result;
  $commitDate->execute($cid);
#  print "Is commitDate [$cid]\n";
  while (my @data =  $commitDate->fetchrow_array()) {
    push @result, $data[0];
  }
  die "this query should always return only one row [Is commitDate][$cid]" . join(":", @result)  unless scalar(@result) <= 1;
#  print "is commitDate [$cid] is [$result[0]]\n";

  $savedCommitDate{$cid} = $result[0];
  return $result[0];
}




sub Get_Baseline
{
    my $i;

    my $q = $dbh->prepare("select cid,ismerge,comdatereal,$distField,$whenField from commits natural join baseline natural join $tableClosest;");
    print STDERR "Reading baseline\n";
    $q->execute();
    while (my ($cid,$ismerge,$comdate, $d, $whenMerged) =  $q->fetchrow_array()) {
        $savedCommitDate{$cid} = $comdate;
        $savedIsMerge{$cid} = $ismerge;
        $baseline{$cid} = $cid;
        if (defined($d)) {
            $savedDistance{$cid} = $d;
            $savedWhen{$cid} = $whenMerged;
        }
        $i++;
    }
    print STDERR "End Reading baseline [$i]\n";
}
g

sub Simple_Query
{
    my ($query) = @_;
    my $q = $dbh->prepare($query);
    $q->execute();
    return $q->fetchrow_array();
}
