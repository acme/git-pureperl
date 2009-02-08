package Git::PurePerl::NewObject;
use Moose;
use MooseX::StrictConstructor;
use Moose::Util::TypeConstraints;

enum 'ObjectKind' => qw(commit tree blob tag);

has 'kind' => ( is => 'ro', isa => 'ObjectKind', required => 1 );
has 'size' => ( is => 'ro', isa => 'Int', required => 0, lazy_build => 1 );
has 'content' => ( is => 'rw', isa => 'Str', required => 0, lazy_build => 1 );
has 'sha1'    => ( is => 'ro', isa => 'Str', required => 0, lazy_build => 1 );

__PACKAGE__->meta->make_immutable;

sub _build_sha1 {
    my $self = shift;
    my $sha1 = Digest::SHA1->new;
    $sha1->add( $self->raw );
    my $sha1_hex = $sha1->hexdigest;
    return $sha1_hex;
}

sub _build_size {
    my $self = shift;
    return length $self->content;
}

sub raw {
    my $self = shift;
    return $self->kind . ' ' . $self->size . "\0" . $self->content;
}

1;
