package Git::PurePerl::NewObject::Tag;
use Moose;
use MooseX::StrictConstructor;
use Moose::Util::TypeConstraints;
extends 'Git::PurePerl::NewObject';

has 'kind' =>
    ( is => 'ro', isa => 'ObjectKind', required => 1, default => 'tag' );
has 'object'  => ( is => 'rw', isa => 'Str', required => 1 );
has 'tag'     => ( is => 'rw', isa => 'Str', required => 1 );
has 'tagger'  => ( is => 'rw', isa => 'Str', required => 1 );
has 'comment' => ( is => 'rw', isa => 'Str', required => 1 );

__PACKAGE__->meta->make_immutable;

1;
