package Git::PurePerl::Object;
use Moose;
use MooseX::StrictConstructor;
use Moose::Util::TypeConstraints;

enum 'ObjectType' => qw(commit tree blob tag);

has 'type'    => ( is => 'ro', isa => 'ObjectType', required => 1 );
has 'size'    => ( is => 'ro', isa => 'Int',        required => 1 );
has 'content' => ( is => 'ro', isa => 'Str',        required => 1 );
has 'sha1'    => ( is => 'ro', isa => 'Str',        required => 1 );

1;
