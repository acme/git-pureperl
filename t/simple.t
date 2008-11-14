#!perl
use strict;
use warnings;
use Test::More tests => 12;
use lib '.';
use Git::PurePerl;

=for shell

How to create test-project:

mkdir test-project
cd test-project
git init
git config user.name "Your Name Comes Here"
git config user.email you@yourdomain.example.com
echo 'hello world' > file.txt
git add .
git commit -a -m "initial commit"
echo 'hello world!' >file.txt
git commit -a -m "add emphasis"
echo "hello world, again" >>file.txt
git commit -a -m "add again"

=cut 

my $git = Git::PurePerl->new( directory => 'test-project' );
my $master = $git->master;
is( $master->kind,   'commit' );
is( $master->size,   256 );
is( $master->sha1,   '785507f54c5cf843189c58cb44281c5c29410118' );
is( $master->tree,   '37b4fcd62571f07408e830f455268891f95cecf5' );
is( $master->parent, '91f71b78e20fa057e565cc09a6293b8302479fb1' );
like( $master->author,
    qr/^Your Name Comes Here <you\@yourdomain.example.com>/ );
like( $master->committer,
    qr/^Your Name Comes Here <you\@yourdomain.example.com>/ );
is( $master->comment, 'add again' );

my $tree              = $git->get_object( $master->tree );
my @directory_entries = $tree->directory_entries;
is( @directory_entries, 1 );
my $directory_entry = $directory_entries[0];
is( $directory_entry->mode,     '100644' );
is( $directory_entry->filename, 'file.txt' );
is( $directory_entry->sha1,     '513feba2e53ebbd2532419ded848ba19de88ba00' );

