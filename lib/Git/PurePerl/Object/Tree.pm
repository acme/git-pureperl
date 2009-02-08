package Git::PurePerl::Object::Tree;
use Moose;
use MooseX::StrictConstructor;
use Moose::Util::TypeConstraints;
extends 'Git::PurePerl::Object';

has 'kind' =>
    ( is => 'ro', isa => 'ObjectKind', required => 1, default => 'tree' );
has 'directory_entries' => (
    is         => 'rw',
    isa        => 'ArrayRef[Git::PurePerl::DirectoryEntry]',
    required   => 0,
    auto_deref => 1,
);

__PACKAGE__->meta->make_immutable;

sub BUILD {
    my $self    = shift;
    my $content = $self->content;
    return unless $content;
    my @directory_entries;
    while ($content) {
        my $space_index = index( $content, ' ' );
        my $mode = substr( $content, 0, $space_index );
        $content = substr( $content, $space_index + 1 );
        my $null_index = index( $content, "\0" );
        my $filename = substr( $content, 0, $null_index );
        $content = substr( $content, $null_index + 1 );
        my $sha1 = unpack( 'H*', substr( $content, 0, 20 ) );
        $content = substr( $content, 20 );
        push @directory_entries,
            Git::PurePerl::DirectoryEntry->new(
            mode     => $mode,
            filename => $filename,
            sha1     => $sha1,
            );
    }
    $self->directory_entries( \@directory_entries );
}

1;
