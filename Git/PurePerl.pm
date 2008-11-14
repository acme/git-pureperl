package Git::PurePerl;
use Moose;
use MooseX::StrictConstructor;
use MooseX::Types::Path::Class;
use Compress::Zlib qw(uncompress);
use Git::PurePerl::DirectoryEntry;
use Git::PurePerl::Object;
use Git::PurePerl::Object::Commit;
use Git::PurePerl::Object::Tree;
use Path::Class;

has 'directory' =>
    ( is => 'ro', isa => 'Path::Class::Dir', required => 1, coerce => 1 );

sub master {
    my $self = shift;
    my $filename
        = file( $self->directory, '.git', 'refs', 'heads', 'master' );
    my $sha1 = $filename->slurp || confess('Missing refs/heads/master');
    chomp $sha1;
    return $self->get_object($sha1);
}

sub get_object {
    my ( $self, $sha1 ) = @_;

    #warn "getting $sha1";
    my $filename = file(
        $self->directory, '.git', 'objects',
        substr( $sha1, 0, 2 ),
        substr( $sha1, 2 )
    );

    #warn $filename;
    my $data = uncompress( $filename->slurp );
    my ( $kind, $size, $content ) = $data =~ /^(\w+) (\d+)\0(.+)$/s;

    #warn "$kind / $size";
    if ( $kind eq 'commit' ) {
        return Git::PurePerl::Object::Commit->new(
            sha1    => $sha1,
            kind    => $kind,
            size    => $size,
            content => $content,
        );
    } elsif ( $kind eq 'tree' ) {
        return Git::PurePerl::Object::Tree->new(
            sha1    => $sha1,
            kind    => $kind,
            size    => $size,
            content => $content,
        );
    } else {
        confess "unknown kind $kind";
    }

}

1;
