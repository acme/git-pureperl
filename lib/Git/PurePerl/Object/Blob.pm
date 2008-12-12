package Git::PurePerl::Object::Blob;
use Moose;
use MooseX::StrictConstructor;
use Moose::Util::TypeConstraints;
extends 'Git::PurePerl::Object';

__PACKAGE__->meta->make_immutable;

1;
