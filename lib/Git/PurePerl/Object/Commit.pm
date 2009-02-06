package Git::PurePerl::Object::Commit;
use Moose;
use MooseX::StrictConstructor;
use Moose::Util::TypeConstraints;
extends 'Git::PurePerl::Object';

has 'kind' =>
    ( is => 'ro', isa => 'ObjectKind', required => 1, default => 'commit' );
has 'tree'      => ( is => 'rw', isa => 'Str', required => 0 );
has 'parent'    => ( is => 'rw', isa => 'Str', required => 0 );
has 'author'    => ( is => 'rw', isa => 'Str', required => 0 );
has 'committer' => ( is => 'rw', isa => 'Str', required => 0 );
has 'comment'   => ( is => 'rw', isa => 'Str', required => 0 );

__PACKAGE__->meta->make_immutable;

sub BUILD {
    my $self = shift;
    return unless $self->content;
    my @lines = split "\n", $self->content;
    while ( my $line = shift @lines ) {
        last unless $line;
        my ( $key, $value ) = split ' ', $line, 2;
        $self->$key($value);
    }
    $self->comment( join "\n", @lines );
}

sub update_content {
    my $self = shift;
    my $content;
    $content .= 'tree ' . $self->tree ."\n";
$content .= "author Leon Brocard <acme\@astray.com> 1226651274 +0000\n";
$content .= "committer Leon Brocard <acme\@astray.com> 1226651274 +0000\n";
$content .= "\n";
$content .= "A comment\n";

    $self->content($content);
}
1;
