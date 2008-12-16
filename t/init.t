#!perl
use strict;
use warnings;
use Test::More tests => 10;
use Git::PurePerl;
use Path::Class;

my $directory = 'test-init';
dir($directory)->rmtree;

my $git = Git::PurePerl->init( directory => $directory );
isa_ok( $git, 'Git::PurePerl' );
