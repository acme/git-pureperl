#!perl
use strict;
use warnings;
use Test::More tests => 34;
use Git::PurePerl;

foreach my $directory qw(test-project test-project-packs) {
    my $git = Git::PurePerl->new( directory => $directory );
    my $master = $git->master;
    is( $master->kind,   'commit' );
    is( $master->size,   256 );
    is( $master->sha1,   'd60f7006a71288b70601fa6057fd3727842a74a0' );
    is( $master->tree,   '37b4fcd62571f07408e830f455268891f95cecf5' );
    is( $master->parent, 'bb99a61fd2035d672d075ea4b72d17ac0d1c193e' );
    like( $master->author,
        qr/^Your Name Comes Here <you\@yourdomain.example.com>/ );
    like( $master->committer,
        qr/^Your Name Comes Here <you\@yourdomain.example.com>/ );
    is( $master->comment, 'add again' );

    my $tree = $git->get_object( $master->tree );
    is( $tree->kind, 'tree' );
    is( $tree->size, 36 );
    my @directory_entries = $tree->directory_entries;
    is( @directory_entries, 1 );
    my $directory_entry = $directory_entries[0];
    is( $directory_entry->mode,     '100644' );
    is( $directory_entry->filename, 'file.txt' );
    is( $directory_entry->sha1, '513feba2e53ebbd2532419ded848ba19de88ba00' );

    my $blob = $git->get_object( $directory_entry->sha1 );
    is( $blob->kind, 'blob' );
    is( $blob->size, 32 );
    is( $blob->content, 'hello world!
hello world, again
'
    );
}
