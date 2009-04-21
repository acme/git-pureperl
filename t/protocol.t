#!perl
use strict;
use warnings;
use Test::More;

BEGIN {
    if ( $^O eq 'MSWin32' ) {
        plan skip_all => 'Windows does NOT have git-daemon yet';
    }
    plan tests => 14;
}
use Git::PurePerl;
use IO::File;
use Path::Class;

# git daemon --verbose --reuseaddr --export-all --base-path=/home/acme/git/git-pureperl

my $directory = 'test-protocol';
dir($directory)->rmtree;

my $git = Git::PurePerl->init( directory => $directory );
isa_ok( $git, 'Git::PurePerl', 'can init' );

$git->clone( 'localhost', '/test-project' );

is( $git->all_sha1s->all,   9 );
is( $git->all_objects->all, 9 );

$git->update_master('0c7b3d23c0f821e58cd20e60d5e63f5ed12ef391');

like( $git->master_sha1, qr/^[a-z0-9]{40}$/ );
my $commit = $git->master;

is( $commit->kind, 'commit' );
is( $commit->size, 256 );
like( $commit->sha1, qr/^[a-z0-9]{40}$/ );
is( $commit->tree_sha1, '37b4fcd62571f07408e830f455268891f95cecf5' );
like( $commit->parent_sha1, qr/^[a-z0-9]{40}$/ );
is( $commit->author->name,     'Your Name Comes Here' );
is( $commit->author->email,    'you@yourdomain.example.com' );
is( $commit->committer->name,  'Your Name Comes Here' );
is( $commit->committer->email, 'you@yourdomain.example.com' );
is( $commit->comment,          'add again' );
