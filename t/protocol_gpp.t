#!perl
use strict;
use warnings;
use Test::More;
BEGIN {
    if ( $^O eq 'MSWin32' ) {
		plan skip_all => 'Windows does NOT have git-daemon yet';
    }
    plan tests => 3;
}
use Git::PurePerl;
use IO::File;
use Path::Class;

my $directory = 'test-protocol';
dir($directory)->rmtree;

my $git = Git::PurePerl->init( directory => $directory );
isa_ok( $git, 'Git::PurePerl', 'can init' );

$git->clone( 'github.com', '/acme/git-pureperl.git' );

ok( $git->all_sha1s->all >= 604 );
ok( $git->all_objects->all >= 604 );
