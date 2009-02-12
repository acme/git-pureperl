#!perl
use strict;
use warnings;
use Git::PurePerl;
use IO::File;
use Path::Class;
use Test::More tests => 15;

# git-daemon --verbose --reuseaddr --export-all /home/acme/git/git-pureperl/test-project

my $protocol = Git::PurePerl::Protocol->new(
    hostname => 'localhost',
    project  => '/home/acme/git/git-pureperl/test-project',
);
isa_ok( $protocol, 'Git::PurePerl::Protocol' );
my $sha1s = $protocol->connect;
is_deeply(
    $sha1s,
    {   'refs/heads/master' => '0c7b3d23c0f821e58cd20e60d5e63f5ed12ef391',
        'HEAD'              => '0c7b3d23c0f821e58cd20e60d5e63f5ed12ef391',
    },
    'received sha1s'
);
my $data = $protocol->fetch_pack('0c7b3d23c0f821e58cd20e60d5e63f5ed12ef391');
like( $data, qr/PACK/, 'have pack file' );

my $filename = 't/0c7b3d23c0f821e58cd20e60d5e63f5ed12ef391.pack';

my $fh = IO::File->new("> $filename") || die $!;
$fh->print($data) || die $!;
$fh->close;

my $directory = 'test-protocol';
dir($directory)->rmtree;

my $git = Git::PurePerl->init( directory => $directory );
isa_ok( $git, 'Git::PurePerl', 'can init' );

# git index-pack
my $pack = Git::PurePerl::Pack->new( filename => $filename );
$pack->create_index($git);

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
