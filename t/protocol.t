#!perl
use strict;
use warnings;
use Git::PurePerl;
use IO::File;
use Path::Class;
use Test::More tests => 12;

# git-daemon --verbose --reuseaddr --export-all /home/acme/git/git-pureperl/test-project

my $directory = 'test-protocol';
dir($directory)->rmtree;

my $git = Git::PurePerl->init( directory => $directory );
isa_ok( $git, 'Git::PurePerl', 'can init' );

$git->clone( 'localhost', '/home/acme/git/git-pureperl/test-project' );

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
like( $commit->author,
    qr/^Your Name Comes Here <you\@yourdomain.example.com>/ );
like( $commit->committer,
    qr/^Your Name Comes Here <you\@yourdomain.example.com>/ );
is( $commit->comment, 'add again' );
