#!/usr/bin/perl

use strict;
use warnings;
use v5.10;
use FindBin qw/$Bin/;
use lib "$Bin/../lib";
use Fund::Utils qw/dbh/;
use Data::Dumper;
use Template;

my $dbh = dbh();

my @rows;
my $sth = $dbh->prepare("SELECT * FROM xingu_huopei JOIN fund ON fund=code ORDER BY RATIO DESC");
$sth->execute();
while (my $row = $sth->fetchrow_hashref) {
    print Dumper(\$row);
    push @rows, $row;
}

my $tt2 = Template->new({
    INCLUDE_PATH => $Bin,
    INTERPOLATE  => 1,               # expand "$var" in plain text
    POST_CHOMP   => 1,               # cleanup whitespace
});
$tt2->process("xingu_huopei.tt2", {
    rows => [@rows],
}, "$Bin/../html/xingu_huopei.html") or die $tt2->error();
