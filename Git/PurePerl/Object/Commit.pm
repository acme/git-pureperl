package Git::PurePerl::Object::Commit;
use Moose;
use MooseX::StrictConstructor;
use Moose::Util::TypeConstraints;
extends 'Git::PurePerl::Object';

has 'tree'      => ( is => 'rw', isa => 'Str', required => 0 );
has 'parent'    => ( is => 'rw', isa => 'Str', required => 0 );
has 'author'    => ( is => 'rw', isa => 'Str', required => 0 );
has 'committer' => ( is => 'rw', isa => 'Str', required => 0 );
has 'comment'   => ( is => 'rw', isa => 'Str', required => 0 );

sub BUILD {
    my $self = shift;
    my @lines = split "\n", $self->content;
    while ( my $line = shift @lines ) {
         last unless $line;
        my ( $key, $value ) = split ' ', $line, 2;
        $self->$key($value);
    }
    $self->comment( join "\n", @lines );
}

1;
