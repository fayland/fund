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

my $DEBUG = $ENV{DEBUG} // 0;

my $sth = $dbh->prepare("SELECT * FROM fund WHERE updated_at < ?");
$sth->execute(time() - 30 * 86400);
while (my $row = $sth->fetchrow_hashref) {
    # $row->{code} = '000646';
    my $url = "http://fund.eastmoney.com/pingzhongdata/" . $row->{code} . ".js";
    say "# get $url";
    my $res = $ua->get($url)->result;
    my $body = $res->body;
    my %data = parse_fund($body);
    say Dumper(\%data) if $DEBUG;
    die "code is not matched: $data{fS_code} vs $row->{code}"
        if $data{fS_code} ne $row->{code};

    # $url = "http://fundf10.eastmoney.com/zcpz_" . $row->{code} . ".html";
    # say "# get $url";
    # $res = $ua->get($url)->result;
    # my $dom = $res->dom;
    # my $tr = $dom->find('table.tzxq tbody tr')->first;
    # my @tds = $tr->find('td')->map('text')->each;
    # say Dumper(\@tds);
    # $tds[1] =~ s/\%//;
    # $tds[2] =~ s/\%//;
    # $tds[3] =~ s/\%//;

    $url = "http://fundf10.eastmoney.com/jjfl_" . $row->{code} . ".html";
    say "# get $url";
    $res = $ua->get($url)->result;
    my $dom = $res->dom;
    my $yunzuofee_text = decode_utf8("运作费用");
    my $shengou_text = decode_utf8("申购费率");
    my $shuhui_text = decode_utf8("赎回费率");
    foreach my $box ($dom->find('div.box')->each) {
        next unless $box->at('label');
        my $html = "$box";
        my $label = $box->at('label')->all_text;
        say "$label -> $html\n---------\n\n" if $DEBUG;
        if (index($label, $yunzuofee_text) > -1) {
            my @tds = $box->find('td.w135')->map('text')->each;
            say Dumper(\@tds) if $DEBUG;
            die "运作费用 td is not equal to 3" unless @tds == 3;
            @tds = map { s/\%(.*?)$//; $_ } @tds;
            $data{guanli_fee} = $tds[0];
            $data{tuoguan_fee} = $tds[1];
            $data{xiaoshou_fee} = $tds[2];
            $data{xiaoshou_fee} = 0 if $data{xiaoshou_fee} eq '---';
        } elsif (index($label, $shengou_text) > -1) {
            my $tr = $box->find('tbody tr')->first;
            if ($tr->at('strike')) {
                my $strike = $tr->at('strike')->all_text;
                $strike =~ s/\%(.*?)$//;
                $data{shengou_fee} = $strike;
            } else {
                my @tds = $tr->find('td')->map('text')->each;
                say Dumper(\@tds) if $DEBUG;
                die "申购费率 td is not equal to 3" unless @tds == 3;
                @tds = map { s/\%(.*?)$//; $_ } @tds;
                $data{shengou_fee} = $tds[2];
            }
        } elsif (index($label, $shuhui_text) > -1) {
            my $x30 = decode_utf8('小于30天');
            my $d30 = decode_utf8('大于等于30天');
            my $d30_2 = decode_utf8('大于30天');
            my @trs = $box->find('tbody tr')->each;
            foreach my $tr (@trs) {
                my @tds = $tr->find('td')->map('text')->each;
                say Dumper(\@tds) if $DEBUG;
                my $text = $tds[1];
                my $fee  = $tds[2]; $fee =~ s/\%(.*?)$//;
                if (index($text, $x30) > -1) {
                    $data{shuhui_x30_fee} = $fee;
                } elsif (index($text, $d30) > -1 || index($text, $d30_2) > -1) {
                    $data{shuhui_d30_fee} = $fee;
                }
            }
        }
    }

    # data fix
    $data{syl_1n} = -100 if $data{syl_1n} eq '';
    $data{syl_6y} = -100 if $data{syl_6y} eq '';
    $data{syl_3y} = -100 if $data{syl_3y} eq '';
    $data{syl_1y} = -100 if $data{syl_1y} eq '';

    $dbh->do("
        UPDATE fund SET
        name = ?, updated_at = ?,
        jingzichan= ?, gupiao_rate= ?, zhaiquan_rate= ?, xianjin_rate= ?, report_date = ?,
        syl_1n = ?, syl_6y = ?, syl_3y = ?, syl_1y = ?,
        shengou_fee = ?, guanli_fee = ?, tuoguan_fee = ?, xiaoshou_fee = ?,
        shuhui_x30_fee = ?, shuhui_d30_fee = ?,
        jigou_rate = ?, geren_rate = ?, neibu_rate = ?
        WHERE code = ?", undef,
        $data{fS_name}, time(),
        # $tds[4], $tds[1], $tds[2], $tds[3], $tds[0],

        # jingzichan= ?, gupiao_rate= ?, zhaiquan_rate= ?, xianjin_rate= ?, report_date = ?,
        $data{Data_assetAllocation}->{series}->[3]->{data}->[-1],
        $data{Data_assetAllocation}->{series}->[0]->{data}->[-1],
        $data{Data_assetAllocation}->{series}->[1]->{data}->[-1],
        $data{Data_assetAllocation}->{series}->[2]->{data}->[-1],
        $data{Data_assetAllocation}->{categories}->[-1],

        $data{syl_1n}, $data{syl_6y}, $data{syl_3y} || 0, $data{syl_1y} || 0,

        $data{shengou_fee} // 100, $data{guanli_fee} // 100, $data{tuoguan_fee} // 100, $data{xiaoshou_fee} // 100,
        $data{shuhui_x30_fee} // 100, $data{shuhui_d30_fee} // 100,

        # jigou_rate = ?, geren_rate = ?, neibu_rate = ?
        $data{Data_holderStructure}->{series}->[0]->{data}->[-1],
        $data{Data_holderStructure}->{series}->[1]->{data}->[-1],
        $data{Data_holderStructure}->{series}->[2]->{data}->[-1],

        $row->{code}
    );
    sleep 5;
}

sub parse_fund {
    my ($body) = @_;

    my %data;
    $body =~ s{/\*(.*?)\*\/}{}sg; # remove comment
    foreach my $line (split(/\;\s*var\s+/, $body)) {
        # say $line;
        my ($k, $v) = split(/\s*=\s*/, $line, 2);
        $v =~ s/^[\'\"]|[\'\"]$//g; # remove ""
        if (grep { $k eq $_ } ('Data_holderStructure', 'Data_assetAllocation')) {
            $v = decode_json($v);
        }
        $data{$k} = $v;
    }

    return %data;
}