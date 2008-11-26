package Git::PurePerl::Object::Tag;
use Moose;
use MooseX::StrictConstructor;
use Moose::Util::TypeConstraints;
extends 'Git::PurePerl::Object';

has 'object'  => ( is => 'rw', isa => 'Str', required => 0 );
has 'tag'     => ( is => 'rw', isa => 'Str', required => 0 );
has 'tagger'  => ( is => 'rw', isa => 'Str', required => 0 );
has 'comment' => ( is => 'rw', isa => 'Str', required => 0 );

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
