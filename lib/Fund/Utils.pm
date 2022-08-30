package Fund::Utils;

use strict;
use warnings;
use base 'Exporter';
use DBI;
use Mojo::UserAgent;

our @EXPORT_OK = qw/dbh ua/;

sub dbh {
    return DBI->connect(
        "DBI:mysql:database=fund:mysql_enable_utf8=1", "root", "perl4ever",
        { PrintError => 1, RaiseError => 1, AutoCommit => 1 }
    );
}

sub ua {
    my $ua = Mojo::UserAgent->new;
    $ua->insecure(1);
    $ua->transactor->name('Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/104.0.0.0 Safari/537.36');
    return $ua;
}

1;