#!perl
use strict;
use warnings;
use Git::PurePerl;
use IO::File;
use Test::More tests => 3;

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
my $pack = $protocol->fetch_pack('0c7b3d23c0f821e58cd20e60d5e63f5ed12ef391');
like( $pack, qr/PACK/, 'have pack file' );

my $fh = IO::File->new("> t/0c7b3d23c0f821e58cd20e60d5e63f5ed12ef391.pack") || die $!;
$fh->print($pack) || die $!;
$fh->close;

# git index-pack
