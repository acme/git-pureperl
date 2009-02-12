package Git::PurePerl::Object;
use Moose;
use MooseX::StrictConstructor;
use Moose::Util::TypeConstraints;

enum 'ObjectKind' => qw(commit tree blob tag);

has 'kind'    => ( is => 'ro', isa => 'ObjectKind',    required => 1 );
has 'size'    => ( is => 'ro', isa => 'Int',           required => 1 );
has 'content' => ( is => 'rw', isa => 'Str',           required => 1 );
has 'sha1'    => ( is => 'ro', isa => 'Str',           required => 1 );
has 'git'     => ( is => 'ro', isa => 'Git::PurePerl', required => 1 );

__PACKAGE__->meta->make_immutable;

1;
