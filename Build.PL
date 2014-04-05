use 5.006;
use strict;
use warnings FATAL => 'all';
use Module::Build;

my $builder = Module::Build->new(
    module_name         => 'MultiSkan',
    license             => 'perl',
    dist_author         => q{Jing <logust79@gmail.com>},
    dist_version_from   => 'lib/MultiSkan.pm',
    release_status      => 'stable',
    configure_requires => {
        'Module::Build' => 0,
    },
    build_requires => {
        'Test::More' => 0,
    },
    requires => {
        'Chart::ErrorBars' => 2,
        'Moose' => 2.12,
        'Carp' => 1.29,
        'GD' => 2.52,
        'Statistics::Lite' => 3.2,
    },
    add_to_cleanup     => [ 'MultiSkan-*' ],
    create_makefile_pl => 'traditional',
);

$builder->create_build_script();
