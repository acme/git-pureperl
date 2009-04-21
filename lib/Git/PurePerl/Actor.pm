package Git::PurePerl::Actor;
use Moose;
use MooseX::StrictConstructor;
use Moose::Util::TypeConstraints;

has 'name'  => ( is => 'ro', isa => 'Str', required => 1 );
has 'email' => ( is => 'ro', isa => 'Str', required => 1 );

__PACKAGE__->meta->make_immutable;

1;
