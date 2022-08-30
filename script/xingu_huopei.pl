#!/usr/bin/perl

use strict;
use warnings;
use v5.10;
use FindBin qw/$Bin/;
use lib "$Bin/../lib";
use Fund::Utils qw/dbh ua/;
use Data::Dumper;
use Mojo::JSON qw/decode_json/;
use Encode;

my $ua = ua();
my $dbh = dbh();

# get 5 pages
foreach my $page (1 .. 5) {
    my $url = "https://fund.eastmoney.com/API/FundDXGJJ.ashx?callback=jQuery18306428571140128803_1661830124724&r=" . time() . "000&m=8&pageindex=$page&sorttype=desc&SFName=RATIO&IsSale=1&_=" . time();
    say "# get $url";
    my $res = $ua->get($url => {
        'X-Requested-With' => 'XMLHttpRequest'
    })->result;
    my $body = $res->body;
    $body =~ s/^jQuery18306428571140128803_1661830124724\(//s;
    $body =~ s/\)[\;\s]*$//s;
    my $w = decode_json($body);
    my $data = decode_json( encode_utf8($w->{Datas}) );

    $dbh->do("DELETE FROM xingu_huopei;") if $page == 1; # clear
    foreach my $row (@$data) {
        say Dumper(\$row);
        $row->{HSGRT} =~ s/\%$//;
        $dbh->do("INSERT INTO xingu_huopei (fund, STKNUM, RATIO, HSGRT) VALUES (?, ?, ?, ?)", undef,
            $row->{FCODE}, $row->{STKNUM}, $row->{RATIO}, $row->{HSGRT});
        $dbh->do("INSERT IGNORE INTO fund (code) VALUES (?)", undef, $row->{FCODE});
    }
    sleep 5;
}

