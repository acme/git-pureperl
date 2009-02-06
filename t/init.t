#!perl
use strict;
use warnings;
use Test::More tests => 16;
use Git::PurePerl;
use Path::Class;

my $directory = 'test-init';
dir($directory)->rmtree;

my $git = Git::PurePerl->init( directory => $directory );
isa_ok( $git, 'Git::PurePerl', 'can init' );

my @all_sha1s = $git->all_sha1s->all;
is( @all_sha1s, 0, 'does not contain any objects' );

my $hello = Git::PurePerl::Object::Blob->new( content => 'hello', );
$git->put_object($hello);
is( $git->get_object('b6fc4c620b67d95f953a5c1c1230aaab5db5a1b0')->content,
    'hello' );

my $there = Git::PurePerl::Object::Blob->new( content => 'there', );
$git->put_object($there);
is( $git->get_object('c78ee1a5bdf46d22da300b68d50bc45c587c3293')->content,
    'there' );

my $hello_de = Git::PurePerl::DirectoryEntry->new(
    mode     => '100644',
    filename => 'hello.txt',
    sha1     => $hello->sha1,
);
my $there_de = Git::PurePerl::DirectoryEntry->new(
    mode     => '100644',
    filename => 'there.txt',
    sha1     => $there->sha1,
);
my $tree = Git::PurePerl::Object::Tree->new(
    kind              => 'tree',
    directory_entries => [ $hello_de, $there_de ]
);
$tree->update_content;
$git->put_object($tree);
my $tree2 = $git->get_object('6d991aebc86bd09e86d74bb84bb9ebfb97e18026');
is( $tree2->kind, 'tree' );
is( $tree2->size, 74 );
my @directory_entries = $tree2->directory_entries;
is( @directory_entries, 2 );
my $directory_entry = $directory_entries[0];
is( $directory_entry->mode,     '100644' );
is( $directory_entry->filename, 'hello.txt' );
is( $directory_entry->sha1,     'b6fc4c620b67d95f953a5c1c1230aaab5db5a1b0' );
my $directory_entry2 = $directory_entries[1];
is( $directory_entry2->mode,     '100644' );
is( $directory_entry2->filename, 'there.txt' );
is( $directory_entry2->sha1,     'c78ee1a5bdf46d22da300b68d50bc45c587c3293' );

my $commit = Git::PurePerl::Object::Commit->new( tree => $tree->sha1 );
$commit->update_content;
$git->put_object($commit);

my $commit2 = $git->get_object('d75f1437e0c19c36f9b52312eeb6b0200dbd22ac');
is( $commit2->tree, $tree->sha1 );

$git = Git::PurePerl->new( directory => $directory );
isa_ok( $git, 'Git::PurePerl', 'can get object' );

@all_sha1s = $git->all_sha1s->all;
is( @all_sha1s, 4, 'contains four objects' );

