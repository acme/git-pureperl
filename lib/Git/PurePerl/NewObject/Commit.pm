package Git::PurePerl::NewObject::Commit;
use Moose;
use MooseX::StrictConstructor;
use Moose::Util::TypeConstraints;
use DateTime;
extends 'Git::PurePerl::NewObject';

has 'kind' =>
    ( is => 'ro', isa => 'ObjectKind', required => 1, default => 'commit' );
has 'tree'   => ( is => 'rw', isa => 'Str',                  required => 1 );
has 'parent' => ( is => 'rw', isa => 'Str',                  required => 0 );
has 'author' => ( is => 'rw', isa => 'Git::PurePerl::Actor', required => 1 );
has 'authored_time' => ( is => 'rw', isa => 'DateTime', required => 1 );
has 'committer' =>
    ( is => 'rw', isa => 'Git::PurePerl::Actor', required => 1 );
has 'committed_time' => ( is => 'rw', isa => 'DateTime', required => 1 );
has 'comment'        => ( is => 'rw', isa => 'Str',      required => 1 );

__PACKAGE__->meta->make_immutable;

sub _build_content {
    my $self = shift;
    my $content;

    $content .= 'tree ' . $self->tree . "\n";
    $content .= 'parent ' . $self->parent . "\n" if $self->parent;
    $content
        .= "author "
        . $self->author->name . ' <'
        . $self->author->email . "> "
        . $self->authored_time->epoch . " "
        . DateTime::TimeZone->offset_as_string( $self->authored_time->offset )
        . "\n";
    $content
        .= "committer "
        . $self->committer->name . ' <'
        . $self->author->email . "> "
        . $self->committed_time->epoch . " "
        . DateTime::TimeZone->offset_as_string(
        $self->committed_time->offset )
        . "\n";
    $content .= "\n";
    my $comment = $self->comment;
    chomp $comment;
    $content .= "$comment\n";

    $self->content($content);
}

1;
