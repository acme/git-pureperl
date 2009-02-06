package Git::PurePerl::Object::Blob;
use Moose;
use MooseX::StrictConstructor;
use Moose::Util::TypeConstraints;
extends 'Git::PurePerl::Object';

has 'kind' =>
    ( is => 'ro', isa => 'ObjectKind', required => 1, default => 'blob' );

__PACKAGE__->meta->make_immutable;

1;
