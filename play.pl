#!perl
use strict;
use warnings;
use lib 'lib';
use Git::PurePerl;

my $git = Git::PurePerl->new(directory => '/home/acme/git/net-amazon-s3-bulk/');

#my $commit = $git->get_object('cda28fd7790a13e4a94ead6391bc227dfa12932f');

my $tree = $git->get_object('90ef5a6828bd983f01aa9625c01fc9647f96b355');

#my $parent = $git->get_object('a89ede7a291bb460fac701864a85cf12bdf4caa9');


#use Compress::Zlib qw(uncompress);
#use File::Slurp;

#my $file = '/home/acme/git/net-amazon-s3-bulk/.git/objects/cd/a28fd7790a13e4a94ead6391bc227dfa12932f';
#my $data = read_file($file);
#warn uncompress($data) ;