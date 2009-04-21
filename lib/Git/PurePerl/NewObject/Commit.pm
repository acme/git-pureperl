package Git::PurePerl::NewObject::Commit;
use Moose;
use MooseX::StrictConstructor;
use Moose::Util::TypeConstraints;
extends 'Git::PurePerl::NewObject';

has 'kind' =>
    ( is => 'ro', isa => 'ObjectKind', required => 1, default => 'commit' );
has 'tree'      => ( is => 'rw', isa => 'Str', required => 1 );
has 'parent'    => ( is => 'rw', isa => 'Str', required => 0 );
has 'author'    => ( is => 'rw', isa => 'Str', required => 0 );
has 'committer' => ( is => 'rw', isa => 'Str', required => 0 );
has 'comment'   => ( is => 'rw', isa => 'Str', required => 0 );

__PACKAGE__->meta->make_immutable;

sub _build_content {
    my $self = shift;
    my $content;
    $content .= 'tree ' . $self->tree . "\n";
    $content .= 'parent ' . $self->parent . "\n" if $self->parent;
    $content .= "author Leon Brocard <acme\@astray.com> 1226651274 +0000\n";
    $content
        .= "committer Leon Brocard <acme\@astray.com> 1226651274 +0000\n";
    $content .= "\n";
    $content .= "A comment\n";

    $self->content($content);
}

1;
