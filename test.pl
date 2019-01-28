use strict;
use warnings;
use lib "lib";
use Test::More;
use DBI;
use DBI::Log::Plugged file => "foo.sql";

my $dbh = DBI->connect("dbi:SQLite:dbname=foo.db", "", "", {RaiseError => 1, PrintError => 0});
my $sth = $dbh->prepare("CREATE TABLE foo (a INT, b INT)");
$sth->execute();

END {
    unlink "foo.db";
    unlink "foo.sql";
};