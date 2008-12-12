package Git::PurePerl;
use Moose;
use MooseX::StrictConstructor;
use MooseX::Types::Path::Class;
use Compress::Zlib qw(uncompress);
use Data::Stream::Bulk;
use Data::Stream::Bulk::Array;
use Data::Stream::Bulk::Path::Class;
use Git::PurePerl::DirectoryEntry;
use Git::PurePerl::Object;
use Git::PurePerl::Object::Blob;
use Git::PurePerl::Object::Commit;
use Git::PurePerl::Object::Tag;
use Git::PurePerl::Object::Tree;
use Git::PurePerl::Pack;
use Path::Class;
our $VERSION = '0.36';

has 'directory' =>
    ( is => 'ro', isa => 'Path::Class::Dir', required => 1, coerce => 1 );

has 'packs' => (
    is         => 'rw',
    isa        => 'ArrayRef[Git::PurePerl::Pack]',
    required   => 0,
    auto_deref => 1,
    lazy_build => 1,
);

__PACKAGE__->meta->make_immutable;

sub BUILD {
    my $self = shift;
    my $git_dir = dir( $self->directory, '.git' );
    unless ( -d $git_dir ) {
        confess $self->directory . ' does not contain a .git directory';
    }
}

sub _build_packs {
    my $self = shift;
    my $pack_dir = dir( $self->directory, '.git', 'objects', 'pack' );
    my @packs;
    foreach my $filename ( $pack_dir->children ) {
        next unless $filename =~ /\.pack$/;
        push @packs, Git::PurePerl::Pack->new( filename => $filename );
    }
    return \@packs;
}

sub master {
    my $self = shift;
    my $master = file( $self->directory, '.git', 'refs', 'heads', 'master' );
    my $sha1;
    if ( -f $master ) {
        $sha1 = $master->slurp || confess('Missing refs/heads/master');
        chomp $sha1;
    } else {
        my $packed_refs = file( $self->directory, '.git', 'packed-refs' );
        my $content = $packed_refs->slurp
            || confess('Missing refs/heads/master');
        foreach my $line ( split "\n", $content ) {
            next if $line =~ /^#/;
            ( $sha1, my $name ) = split ' ', $line;
            last if $name eq 'refs/heads/master';
        }
    }
    return $self->get_object($sha1);
}

sub get_object {
    my ( $self, $sha1 ) = @_;
    return $self->get_object_packed($sha1) || $self->get_object_loose($sha1);
}

sub get_object_packed {
    my ( $self, $sha1 ) = @_;

    foreach my $pack ( $self->packs ) {
        my ( $kind, $size, $content ) = $pack->get_object($sha1);
        if ( $kind && $size && $content ) {
            return $self->create_object( $sha1, $kind, $size, $content );
        }
    }
}

sub get_object_loose {
    my ( $self, $sha1 ) = @_;

    my $filename = file(
        $self->directory, '.git', 'objects',
        substr( $sha1, 0, 2 ),
        substr( $sha1, 2 )
    );

    my $compressed = $filename->slurp;
    my $data       = uncompress($compressed);
    my ( $kind, $size, $content ) = $data =~ /^(\w+) (\d+)\0(.+)$/s;

    return $self->create_object( $sha1, $kind, $size, $content );
}

sub create_object {
    my ( $self, $sha1, $kind, $size, $content ) = @_;
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
    } elsif ( $kind eq 'blob' ) {
        return Git::PurePerl::Object::Blob->new(
            sha1    => $sha1,
            kind    => $kind,
            size    => $size,
            content => $content,
        );
    } elsif ( $kind eq 'tag' ) {
        return Git::PurePerl::Object::Tag->new(
            sha1    => $sha1,
            kind    => $kind,
            size    => $size,
            content => $content,
        );
    } else {
        confess "unknown kind $kind: $content";
    }
}

sub all_sha1s {
    my $self = shift;
    my $dir = dir( $self->directory, '.git', 'objects' );

    my $files = Data::Stream::Bulk::Path::Class->new(
        dir        => $dir,
        only_files => 1,
    );
    my @streams;
    push @streams, Data::Stream::Bulk::Filter->new(
        filter => sub {
            [   map { m{([a-z0-9]{2})/([a-z0-9]{38})}; $1 . $2 }
                    grep {m{/[a-z0-9]{2}/}} @$_
            ];
        },
        stream => $files,
    );

    foreach my $pack ( $self->packs ) {
        push @streams,
            Data::Stream::Bulk::Array->new( array => [ $pack->all_sha1s ], );
    }

    return Data::Stream::Bulk::Cat->new( streams => \@streams, );
}

1;

__END__

=head1 NAME

Git::PurePerl - A Pure Perl interface to Git repositories

=head1 SYNOPSIS

    my $git = Git::PurePerl->new(
        directory => '/path/to/git/'
    );
    $git->master->committer;
    $git->master->comment;
    $git->get_object($git->master->tree);

=head1 DESCRIPTION

This module is a Pure Perl interface to Git repositories.

It was mostly based on Grit L<http://grit.rubyforge.org/>.

=head1 METHODS

=over 4

=item master

=item get_object

=item get_object_packed

=item get_object_loose

=item create_object

=item all_sha1s

=back

=head1 AUTHOR

Leon Brocard <acme@astray.com>

=head1 COPYRIGHT

Copyright (C) 2008, Leon Brocard.

=head1 LICENSE

This module is free software; you can redistribute it or 
modify it under the same terms as Perl itself.
