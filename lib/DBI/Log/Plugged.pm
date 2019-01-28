package DBI::Log::Plugged;

use 5.006;
no strict;
no warnings;
use DBI;
use Sub::Override;

our $VERSION = "0.08";
our %opts    = (
    file   => $file,
    trace  => 0,
    timing => 0,
    fh     => undef,
);

warn "Use fine!";

my $orig_execute            = \&DBI::st::execute;
my $orig_selectall_arrayref = \&DBI::db::selectall_arrayref;
my $orig_selectcol_arrayref = \&DBI::db::selectcol_arrayref;
my $orig_selectall_hashref  = \&DBI::db::selectall_hashref;
my $orig_selectrow_arrayref = \&DBI::db::selectrow_arrayref;
my $orig_selectrow_array    = \&DBI::db::selectrow_array;
my $orig_selectrow_hashref  = \&DBI::db::selectrow_hashref;
my $orig_do                 = \&DBI::db::do;

warn "Ref 1 : ". \&DBI::st::execute;

my $sub = Sub::Override->new;
$sub->replace( 'DBI::st::execute',            \&_execute );
$sub->replace( 'DBI::db::selectall_arrayref', \&_selectall_arrayref );
$sub->replace( 'DBI::db::selectcol_arrayref', \&_selectcol_arrayref );
$sub->replace( 'DBI::db::selectall_hashref',  \&_selectall_hashref );
$sub->replace( 'DBI::db::selectrow_arrayref', \&_selectrow_arrayref );
$sub->replace( 'DBI::db::selectrow_array',    \&_selectrow_array );
$sub->replace( 'DBI::db::selectrow_hashref',  \&_selectrow_hashref );
$sub->replace( 'DBI::db::do',                 \&_do );

warn "It must be same : ". \&_execute ." ". \&DBI::st::execute;

sub _execute {
    my ( $sth, @args ) = @_;
    warn "Execute is working!";
    my $log = dbilog( "execute", $sth->{Database}, $sth->{Statement}, \@args );
    my $retval = $orig_execute->( $sth, @args );
    dbilog2($log);
    return $retval;
}

sub _selectall_arrayref {
    my ( $dbh, $query, $yup, @args ) = @_;
    my $log    = dbilog( "selectall_arrayref", $dbh, $query, \@args );
    my $retval = $orig_selectall_arrayref->( $dbh, $query, $yup, @args );
    dbilog2($log);
    return $retval;
}

sub _selectcol_arrayref {
    my ( $dbh, $query, $yup, @args ) = @_;
    my $log    = dbilog( "selectcol_arrayref", $dbh, $query, \@args );
    my $retval = $orig_selectcol_arrayref->( $dbh, $query, $yup, @args );
    dbilog2($log);
    return $retval;
}

sub _selectall_hashref {
    my ( $dbh, $query, $yup, @args ) = @_;
    my $log    = dbilog( "selectall_hashref", $dbh, $query, \@args );
    my $retval = $orig_selectall_hashref->( $dbh, $query, $yup, @args );
    dbilog2($log);
    return $retval;
}

sub _selectrow_arrayref {
    my ( $dbh, $query, $yup, @args ) = @_;
    my $log    = dbilog( "selectrow_arrayref", $dbh, $query, \@args );
    my $retval = $orig_selectrow_arrayref->( $dbh, $query, $yup, @args );
    dbilog2($log);
    return $retval;
}

sub _selectrow_array {
    my ( $dbh, $query, $yup, @args ) = @_;
    my $log    = dbilog( "selectrow_array", $dbh, $query, \@args );
    my $retval = $orig_selectrow_array->( $dbh, $query, $yup, @args );
    dbilog2($log);
    return $retval;
}

sub _selectrow_hashref {
    my ( $dbh, $query, $yup, @args ) = @_;
    my $log    = dbilog( "selectrow_hashref", $dbh, $query, \@args );
    my $retval = $orig_selectrow_hashref->( $dbh, $query, $yup, @args );
    dbilog2($log);
    return $retval;
}

sub _do {
    my ( $dbh, $query, $yup, @args ) = @_;
    my $log    = dbilog( "do", $dbh, $query, \@args );
    my $retval = $orig_do->( $dbh, $query, $yup, @args );
    dbilog2($log);
    return $retval;
}

sub import {
    my ( $package, %args ) = @_;
    for my $key ( keys %args ) {
        $opts{$key} = $args{$key};
    }
    if ( !$opts{file} ) {
        $opts{fh} = \*STDERR;
    }
    else {
        my $file2 = $opts{file};
        if ( $file2 =~ m{^~/} ) {
            my $home = $ENV{HOME} || ( getpwuid($<) )[7];
            $file2 =~ s{^~/}{$home/};
        }
        open $opts{fh}, ">>", $file2 or die "Can't open $opts{file}: $!";
    }
}

sub dbilog {
    my ( $name, $dbh, $query, $args ) = @_;
    my $log    = {};
    my $mcount = 0;
    for ( my $i = 0 ; my @caller = caller($i) ; $i++ ) {
        my ( $package, $file, $line, $sub ) = @caller;
        if ( $package eq "DBI::Log::Plugged" ) {
            $mcount++;
            if ( $mcount > 1 ) {
                $log->{skip} = 1;
                return $log;
            }
        }
    }
    my $stack = "";
    for ( my $i = 0 ; my @caller = caller($i) ; $i++ ) {
        my ( $package, $file, $line, $sub ) = @caller;
        if ( $package eq "DBI::Log::Plugged" ) {
            next;
        }
        $sub =~ s/.*:://;
        $sub = $name if !$stack;
        $stack .= "-- $sub $file $line\n";
        last if !$opts{trace};
    }
    if ($dbh) {
        my $i = 0;
        $query =~ s{\?}{$dbh->quote($args->[$i++])}eg;
    }
    $query =~ s/^\s*\n|\s*$//g;
    $info = "-- " . scalar( localtime() ) . "\n";
    print { $opts{fh} } "$info$stack$query\n";
    $log->{time1} = time();
    return $log;
}

sub dbilog2 {
    my ($log) = @_;
    return if $log->{skip};
    if ( $opts{timing} ) {
        $log->{time2} = time();
        my $diff = $log->{time2} - $log->{time1};
        print { $opts{fh} } "-- ${diff}s\n";
    }
    print { $opts{fh} } "\n";
}

1;

__END__

=encoding utf8

=head1 NAME

DBI::Log2 - Log all DBI queries

=head1 SYNOPSIS

    use DBI::Log2;

=head1 DESCRIPTION

You can use this module to log all queries that are made with DBI.
You just need to include it in your script and it will work
automatically.  By default, it will send output to STDERR, which
is useful for command line scripts and for CGI scripts since STDERR
will appear in the error log.

If you want to log elsewhere, set the file option (on the use line) to
a different location.

    use DBI::Log2 file => "~/querylog.sql";

Each query in the log is prepended with the date and the place in
the code where it was run from. You can add a full stack trace by
setting the trace option (on the use line).

    use DBI::Log2 trace => 1;

If you want timing information about how long the queries took to
run add the timing option (on the use line).

    use DBI::Log2 timing => 1;

The log is formatted as SQL, so if you look at it in an editor, it
might be highlighted. This is what the output may look like:

    -- Fri Sep 11 17:31:18 2015
    -- execute t/test.t 18
    CREATE TABLE foo (a INT, b INT)

    -- Fri Sep 11 17:31:18 2015
    -- do t/test.t 21
    INSERT INTO foo VALUES ('1', '2')

    -- Fri Sep 11 17:31:18 2015
    -- selectcol_arrayref t/test.t 24
    SELECT * FROM foo

    -- Fri Sep 11 17:31:18 2015
    -- do t/test.t 27
    -- (eval) t/test.t 27
    INSERT INTO bar VALUES ('1', '2')

There is a built-in way to log with DBI, which can be enabled with
DBI->trace(1), but the output is not easy to read through.

This module integrates placeholder values into the query, so the
log will contain valid queries.

=head1 METACPAN

L<https://metacpan.org/pod/DBI::Log>

=head1 REPOSITORY

L<https://github.com/zorgnax/dbilog>

=head1 AUTHOR

Jacob Gelbman, E<lt>gelbman@gmail.comE<gt>

=head1 CONTRIBUTORS

Árpád Szász, E<lt>arpad.szasz@plenum.roE<gt>

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2015 by Jacob Gelbman

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either Perl version 5.18.2 or,
at your option, any later version of Perl 5 you may have available.

=cut
