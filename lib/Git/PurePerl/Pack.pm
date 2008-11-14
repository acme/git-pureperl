package Git::PurePerl::Pack;
use Moose;
use MooseX::StrictConstructor;
use MooseX::Types::Path::Class;
use Compress::Raw::Zlib;
use IO::File;

has 'filename' =>
    ( is => 'ro', isa => 'Path::Class::File', required => 1, coerce => 1 );

has 'version' => ( is => 'rw', isa => 'Int', required => 0 );

has 'offsets' =>
    ( is => 'rw', isa => 'ArrayRef[Int]', required => 0, auto_deref => 1, );
has 'size' => ( is => 'rw', isa => 'Int', required => 0 );

my @TYPES = ( 'none', 'commit', 'tree', 'blob', 'tag', '', 'ofs_delta',
    'ref_delta' );
my $OBJ_NONE      = 0;
my $OBJ_COMMIT    = 1;
my $OBJ_TREE      = 2;
my $OBJ_BLOB      = 3;
my $OBJ_TAG       = 4;
my $OBJ_OFS_DELTA = 6;
my $OBJ_REF_DELTA = 7;

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
    my $self = shift;
    my $fh   = $self->open_index;
    $fh->read( my $signature, 4 );
    $fh->read( my $version,   4 );

    if ( $signature eq "\377tOc" ) {
        confess("Unknown version") if $version != 2;
    } else {
        $version = 1;
    }
    $self->version($version);
    my @offsets = (0);
    foreach my $i ( 0 .. $FanOutCount - 1 ) {
        $fh->seek( $i * $IdxOffsetSize, 0 );
        $fh->read( my $data, $IdxOffsetSize );
        my $offset = unpack( 'N', $data );
        confess("pack has discontinuous index") if $offset < $offsets[-1];
        push @offsets, $offset;
    }
    $self->size( $offsets[-1] );
}

sub open_index {
    my $self     = shift;
    my $filename = $self->filename;
    my $index_filename = $filename;
    $index_filename =~ s/\.pack/.idx/;
    my $fh = IO::File->new($index_filename) || confess($!);
    return $fh;
}

sub open_pack {
    my $self     = shift;
    my $filename = $self->filename;
    my $fh       = IO::File->new($filename) || confess($!);
    return $fh;
}

sub get_object {
    my ( $self, $want_sha1 ) = @_;
    my $fh  = $self->open_index;
    my $pos = $OffsetStart;
    foreach my $i ( 1 .. $self->size ) {
        $fh->seek( $pos, 0 ) || die $!;
        $fh->read( my $data, $OffsetSize ) || die $!;
        my $offset = unpack( 'N', $data );
        $fh->read( $data, $SHA1Size ) || die $!;
        my $sha1 = unpack( 'H*', $data );
        if ( $sha1 eq $want_sha1 ) {
            return $self->unpack_object($offset);
        }
        $pos += $EntrySize;
    }
    return;
}

sub unpack_object {
    my ( $self, $offset ) = @_;
    my $fh = $self->open_pack;

    $fh->seek( $offset, 0 ) || die $!;

    $fh->read( my $c, 1 ) || die $!;
    $c = unpack( 'C', $c ) || die $!;

    my $size = ( $c & 0xf );
    my $type = ( $c >> 4 ) & 7;

    my $shift = 4;
    $offset++;

    while ( ( $c & 0x80 ) != 0 ) {
        $fh->read( $c, 1 ) || die $!;
        $c = unpack( 'C', $c ) || die $!;
        $size |= ( ( $c & 0x7f ) << $shift );
        $shift  += 7;
        $offset += 1;
    }

    $type = $TYPES[$type];

    if ( $type eq 'ofs_delta' || $type eq 'ref_delta' ) {
        die "deltified";

#            data, type = unpack_deltified(packfile, type, offset, obj_offset, size, options)

    } elsif ( $type eq 'commit'
        || $type eq 'tree'
        || $type eq 'blob'
        || $type eq 'tag' )
    {
        my $content = $self->read_compressed( $fh, $offset, $size );
        return ( $type, $size, $content );
    } else {
        confess "invalid type $type";
    }
}

sub read_compressed {
    my ( $self, $fh, $offset, $size ) = @_;
    $fh->seek( $offset, 0 ) || die $!;
    my ( $deflate, $status ) = Compress::Raw::Zlib::Inflate->new(
        -AppendOutput => 1,
        -ConsumeInput => 0
    );

    my $out = "";
    while ( length($out) < $size ) {
        $fh->read( my $block, 4096 ) || die $!;
        my $status = $deflate->inflate( $block, $out );
    }
    confess "$out is not $size" unless length($out) == $size;
    return $out;
}

1;
