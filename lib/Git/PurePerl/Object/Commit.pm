package Git::PurePerl::Object::Commit;
use Moose;
use MooseX::StrictConstructor;
use Moose::Util::TypeConstraints;
extends 'Git::PurePerl::Object';

has 'kind' =>
    ( is => 'ro', isa => 'ObjectKind', required => 1, default => 'commit' );
has 'tree_sha1'   => ( is => 'rw', isa => 'Str', required => 0 );
has 'parent_sha1' => ( is => 'rw', isa => 'Str', required => 0 );
has 'author'      => ( is => 'rw', isa => 'Str', required => 0 );
has 'committer'   => ( is => 'rw', isa => 'Str', required => 0 );
has 'comment'     => ( is => 'rw', isa => 'Str', required => 0 );

__PACKAGE__->meta->make_immutable;

my %method_map = (
    'tree'   => 'tree_sha1',
    'parent' => 'parent_sha1',
);

sub BUILD {
    my $self = shift;
    return unless $self->content;
    my @lines = split "\n", $self->content;
    while ( my $line = shift @lines ) {
        last unless $line;
        my ( $key, $value ) = split ' ', $line, 2;
        $key = $method_map{$key} || $key;
        $self->$key($value);
    }
    $self->comment( join "\n", @lines );
}

sub tree {
    my $self = shift;
    return $self->git->get_object( $self->tree_sha1 );
}

sub parent {
    my $self = shift;
    return $self->git->get_object( $self->parent_sha1 );
}

1;
