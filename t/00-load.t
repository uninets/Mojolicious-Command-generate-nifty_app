#!perl -T
use 5.006;
use strict;
use warnings FATAL => 'all';
use Test::More;

plan tests => 1;

BEGIN {
    use_ok( 'Mojolicious::Command::generate::dbic_auth_model' ) || print "Bail out!\n";
}

diag( "Testing Mojolicious::Command::generate::dbic_auth_model $Mojolicious::Command::generate::dbic_auth_model::VERSION, Perl $], $^X" );
