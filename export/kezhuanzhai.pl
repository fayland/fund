#!/usr/bin/perl

use strict;
use warnings;
use v5.10;
use FindBin qw/$Bin/;
use lib "$Bin/../lib";
use Fund::Utils qw/dbh/;
use Data::Dumper;
use Text::CSV_XS;
use Encode;

my $dbh = dbh();
my $csv = Text::CSV_XS->new({ binary => 1, auto_diag => 1 });

open(my $fh, '>', 'kezhuanzhai.csv');
$csv->say($fh, ['代码', '名称', '比较基准', '1年涨幅', '6月涨幅', '3月涨幅', '1月涨幅', '机构占比', '规模']);

my $kezhuanzhai_text = "可转债";

my $sth = $dbh->prepare("SELECT * FROM fund WHERE type='zhaiquan' AND name <> ''");
$sth->execute();
while (my $row = $sth->fetchrow_hashref) {
    print Dumper(\$row);
    next unless index($row->{jizhun}, $kezhuanzhai_text) > -1;
    $csv->say($fh, [
        'F' . $row->{code},
        $row->{name},
        $row->{jizhun},
        $row->{syl_1n},
        $row->{syl_6y},
        $row->{syl_3y},
        $row->{syl_1y},
        $row->{jigou_rate},
        $row->{guimo},
    ]);
}

close($fh);
