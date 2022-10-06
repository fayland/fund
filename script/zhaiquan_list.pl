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

# http://fund.eastmoney.com/daogou/#dt4;ftzq;rs;sd;ed;pr;cp;rt;tp;rk;se;nx;sc1n;stdesc;pi2;pn20;zfdiy;shlist

foreach my $page (1 .. 137) {
    my $url = "http://fund.eastmoney.com/data/FundGuideapi.aspx?dt=4&ft=zq&sd=&ed=&sc=1n&st=desc&pi=$page&pn=20&zf=diy&sh=list&rnd=" . rand();
    say "# get $url";
    my $res = $ua->get($url => {
        'X-Requested-With' => 'XMLHttpRequest'
    })->result;
    my $body = $res->body;
    # "fcodes":"008652,008686,008952,008953,010084,010085,008687,519519,460003,164606,008731,008732,002377,002644,006889,009582,161614,485022,004366,002645,"
    my ($fcodes) = ($body =~ /"fcodes":"(.*?)"/);
    die $body unless $fcodes;

    say "# INSERT $fcodes";
    foreach my $code (split(/\,/, $fcodes)) {
        $code =~ s/\D+//g;
        next unless $code;
        $dbh->do("INSERT INTO fund (code, type) VALUES (?, 'zhaiquan') ON DUPLICATE KEY UPDATE type=VALUES(type)", undef, $code);
    }
    sleep 5;
}

