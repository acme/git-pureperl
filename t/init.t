#!perl
use strict;
use warnings;
use Test::More tests => 4;
use Git::PurePerl;
use Path::Class;

my $directory = 'test-init';
dir($directory)->rmtree;

my $git = Git::PurePerl->init( directory => $directory );
isa_ok( $git, 'Git::PurePerl', 'can init' );

my @all_sha1s = $git->all_sha1s->all;
is( @all_sha1s, 0, 'does not contain any objects' );

my $hello = Git::PurePerl::Object::Blob->new(
    kind    => 'blob',
    size    => 5,
    content => 'hello',
);
$git->put_object($hello);
is( $git->get_object('b6fc4c620b67d95f953a5c1c1230aaab5db5a1b0')->content,
    'hello' );

my $there = Git::PurePerl::Object::Blob->new(
    kind    => 'blob',
    size    => 5,
    content => 'there',
);
$git->put_object($there);
is( $git->get_object('c78ee1a5bdf46d22da300b68d50bc45c587c3293')->content,
    'there' );
