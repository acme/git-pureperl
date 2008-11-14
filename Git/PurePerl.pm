package Git::PurePerl;
use Moose;
use MooseX::StrictConstructor;
use MooseX::Types::Path::Class;
use Compress::Zlib qw(uncompress);
use Git::PurePerl::Object;
use Git::PurePerl::Object::Commit;
use Git::PurePerl::Object::Tree;
use Path::Class;

has 'directory' =>
    ( is => 'ro', isa => 'Path::Class::Dir', required => 1, coerce => 1 );

sub get_object {
    my ( $self, $sha1 ) = @_;
    warn "getting $sha1";
    my $filename = file(
        $self->directory, '.git', 'objects',
        substr( $sha1, 0, 2 ),
        substr( $sha1, 2 )
    );
    warn $filename;
    my $data = uncompress( $filename->slurp );
    my ( $type, $size, $content ) = $data =~ /^(\w+) (\d+)\0(.+)$/s;
    warn "$type / $size / $content";
    if ( $type eq 'commit' ) {
        return Git::PurePerl::Object::Commit->new(
            sha1    => $sha1,
            type    => $type,
            size    => $size,
            content => $content,
        );
    } elsif ( $type eq 'tree' ) {
        return Git::PurePerl::Object::Tree->new(
            sha1    => $sha1,
            type    => $type,
            size    => $size,
            content => $content,
        );
    } else {
        confess "unknown type $type";
    }

}

1;
