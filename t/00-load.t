#!perl
use 5.006;
use strict;
use warnings FATAL => 'all';
use Test::More;

plan tests => 1;

BEGIN {
    use_ok( 'Mojolicious::Command::generate::nifty_app' ) || print "Bail out!\n";
}

diag( "Testing Mojolicious::Command::generate::nifty_app, Perl $], $^X" );
