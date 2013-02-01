use 5.006;
use strict;
use warnings FATAL => 'all';
use Module::Build;

my $builder = Module::Build->new(
    module_name         => 'Mojolicious::Command::generate::nifty_app',
    license             => 'Artistic_2_0',
    dist_author         => q{Matthias Krull <m.krull@uninets.eu>},
    dist_abstract       => q{Generate a simple application with DBIx::Class authentication.},
    dist_version_from   => 'lib/Mojolicious/Command/generate/nifty_app.pm',
    release_status      => 'stable',
    configure_requires => {
        'Module::Build' => 0,
    },
    build_requires => {
        'Test::More' => 0,
    },
    requires => {
        'Mojolicious'       => 3.69,
        'YAML'              => 0,
        'DBIx::Class'       => 0,
        'DBIx::Connector'   => 0,
        'String::Random'    => 0,
        'Crypt::Passwd::XS' => 0,
    },
    meta_merge => {
        resources => {
            repository => 'https://github.com/mugenken/Mojolicious-Command-generate-nifty_app'
        }
    },
    add_to_cleanup     => [ 'Mojolicious-Command-generate-nifty_app-* Build _build MYMETA.*' ],
    create_makefile_pl => 'traditional',
);

$builder->create_build_script();
