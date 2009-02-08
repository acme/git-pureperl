package Git::PurePerl::NewObject::Tree;
use Moose;
use MooseX::StrictConstructor;
use Moose::Util::TypeConstraints;
extends 'Git::PurePerl::NewObject';

has 'kind' =>
    ( is => 'ro', isa => 'ObjectKind', required => 1, default => 'tree' );
has 'directory_entries' => (
    is         => 'rw',
    isa        => 'ArrayRef[Git::PurePerl::DirectoryEntry]',
    required   => 1,
    auto_deref => 1,
);

__PACKAGE__->meta->make_immutable;

sub _build_content {
    my $self = shift;
    my $content;
    foreach my $de ( $self->directory_entries ) {
        $content
            .= $de->mode . ' '
            . $de->filename . "\0"
            . pack( 'H*', $de->sha1 );
    }
    $self->content($content);
}

1;
