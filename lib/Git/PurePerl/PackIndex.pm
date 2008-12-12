package Git::PurePerl::PackIndex;
use Moose;
use MooseX::StrictConstructor;
use IO::File;

has 'filename' =>
    ( is => 'ro', isa => 'Path::Class::File', required => 1, coerce => 1 );

has 'fh' => ( is => 'rw', isa => 'IO::File', required => 0 );

has 'offsets' =>
    ( is => 'rw', isa => 'ArrayRef[Int]', required => 0, auto_deref => 1, );
has 'size' => ( is => 'rw', isa => 'Int', required => 0 );

__PACKAGE__->meta->make_immutable;

my $FanOutCount   = 256;
my $SHA1Size      = 20;
my $IdxOffsetSize = 4;
my $OffsetSize    = 4;
my $CrcSize       = 4;
my $OffsetStart   = $FanOutCount * $IdxOffsetSize;
my $SHA1Start     = $OffsetStart + $OffsetSize;
my $EntrySize     = $OffsetSize + $SHA1Size;
my $EntrySizeV2   = $SHA1Size + $CrcSize + $OffsetSize;

sub BUILD {
    my $self     = shift;
    my $filename = $self->filename;

    my $fh = IO::File->new($filename) || confess($!);
    $self->fh($fh);

    my @offsets = (0);
    $fh->seek( $self->global_offset, 0 );
    foreach my $i ( 0 .. $FanOutCount - 1 ) {
        $fh->read( my $data, $IdxOffsetSize );
        my $offset = unpack( 'N', $data );
        confess("pack has discontinuous index") if $offset < $offsets[-1];
        push @offsets, $offset;
    }
    $self->offsets( \@offsets );
    $self->size( $offsets[-1] );
}

1;
