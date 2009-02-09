#!perl
use strict;
use warnings;
use Test::More tests => 162;
use Git::PurePerl;
use Path::Class;

my $checkout_directory = dir('t/checkout');

foreach my $directory qw(test-project test-project-packs test-project-packs2)
{
    my $git = Git::PurePerl->new( directory => $directory );
    my $commit = $git->master;

    is( $commit->kind, 'commit' );
    is( $commit->size, 256 );
    like( $commit->sha1, qr/^[a-z0-9]{40}$/ );
    is( $commit->tree, '37b4fcd62571f07408e830f455268891f95cecf5' );
    like( $commit->parent, qr/^[a-z0-9]{40}$/ );
    like( $commit->author,
        qr/^Your Name Comes Here <you\@yourdomain.example.com>/ );
    like( $commit->committer,
        qr/^Your Name Comes Here <you\@yourdomain.example.com>/ );
    is( $commit->comment, 'add again' );

    my $tree = $git->get_object( $commit->tree );
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

    $commit = $git->get_object( $commit->parent );
    is( $commit->kind, 'commit' );
    is( $commit->size, 259 );
    like( $commit->sha1, qr/^[a-z0-9]{40}$/ );
    is( $commit->tree, 'd0492b368b66bdabf2ac1fd8c92b39d3db916e59' );
    like( $commit->parent, qr/^[a-z0-9]{40}$/ );
    like( $commit->author,
        qr/^Your Name Comes Here <you\@yourdomain.example.com>/ );
    like( $commit->committer,
        qr/^Your Name Comes Here <you\@yourdomain.example.com>/ );
    is( $commit->comment, 'add emphasis' );

    $tree = $git->get_object( $commit->tree );
    is( $tree->kind, 'tree' );
    is( $tree->size, 36 );
    @directory_entries = $tree->directory_entries;
    is( @directory_entries, 1 );
    $directory_entry = $directory_entries[0];
    is( $directory_entry->mode,     '100644' );
    is( $directory_entry->filename, 'file.txt' );
    is( $directory_entry->sha1, 'a0423896973644771497bdc03eb99d5281615b51' );

    $blob = $git->get_object( $directory_entry->sha1 );
    is( $blob->kind, 'blob' );
    is( $blob->size, 13 );
    is( $blob->content, 'hello world!
'
    );

    $commit = $git->get_object( $commit->parent );
    is( $commit->kind, 'commit' );
    is( $commit->size, 213 );
    like( $commit->sha1, qr/^[a-z0-9]{40}$/ );
    is( $commit->tree,   '92b8b694ffb1675e5975148e1121810081dbdffe' );
    is( $commit->parent, undef );
    like( $commit->author,
        qr/^Your Name Comes Here <you\@yourdomain.example.com>/ );
    like( $commit->committer,
        qr/^Your Name Comes Here <you\@yourdomain.example.com>/ );
    is( $commit->comment, 'initial commit' );

    $tree = $git->get_object( $commit->tree );
    is( $tree->kind, 'tree' );
    is( $tree->size, 36 );
    @directory_entries = $tree->directory_entries;
    is( @directory_entries, 1 );
    $directory_entry = $directory_entries[0];
    is( $directory_entry->mode,     '100644' );
    is( $directory_entry->filename, 'file.txt' );
    is( $directory_entry->sha1, '3b18e512dba79e4c8300dd08aeb37f8e728b8dad' );

    $blob = $git->get_object( $directory_entry->sha1 );
    is( $blob->kind, 'blob' );
    is( $blob->size, 12 );
    is( $blob->content, 'hello world
'
    );

    is( $git->all_sha1s->all, 9 );

    $checkout_directory->rmtree;
    $checkout_directory->mkpath;
    $git->checkout($checkout_directory);
    is_deeply( [ $checkout_directory->children ],
        ['t/checkout/file.txt'], 'checkout has one file' );
    is( file('t/checkout/file.txt')->slurp, 'hello world!
hello world, again
', 'checkout has latest content'
    );
}
