package Git::PurePerl::Pack;
use Moose;
use MooseX::StrictConstructor;
use MooseX::Types::Path::Class;
use Compress::Raw::Zlib;
use IO::File;

has 'filename' =>
    ( is => 'ro', isa => 'Path::Class::File', required => 1, coerce => 1 );

has 'version'       => ( is => 'rw', isa => 'Int', required => 0 );
has 'global_offset' => ( is => 'rw', isa => 'Int', required => 0 );

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
    $version = unpack( 'N', $version );

    if ( $signature eq "\377tOc" ) {
        confess("Unknown version") if $version != 2;
    } else {
        $version = 1;
    }
    $self->version($version);

    if ( $version == 1 ) {
        $self->global_offset(0);
    } else {
        $self->global_offset(8);
    }

    my @offsets = (0);
    foreach my $i ( 0 .. $FanOutCount - 1 ) {
        $fh->seek( ( $i * $IdxOffsetSize ) + $self->global_offset, 0 );
        $fh->read( my $data, $IdxOffsetSize );
        my $offset = unpack( 'N', $data );
        confess("pack has discontinuous index") if $offset < $offsets[-1];
        push @offsets, $offset;
    }

    $self->size( $offsets[-1] );
}

sub open_index {
    my $self           = shift;
    my $filename       = $self->filename;
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

    if ( $self->version == 1 ) {
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

    } else {

        my $fh = $self->open_index;
        my @data;
        my $pos = $OffsetStart;
        foreach my $i ( 0 .. $self->size - 1 ) {
            $fh->seek( $pos + $self->global_offset, 0 ) || die $!;
            $fh->read( my $sha1, $SHA1Size ) || die $!;
            $data[$i] = [ unpack( 'H*', $sha1 ), 0, 0 ];
            $pos += $SHA1Size;
        }
        foreach my $i ( 0 .. $self->size - 1 ) {
            $fh->seek( $pos + $self->global_offset, 0 ) || die $!;
            $fh->read( my $crc, $CrcSize ) || die $!;
            $data[$i]->[1] = unpack( 'H*', $crc );
            $pos += $CrcSize;
        }
        foreach my $i ( 0 .. $self->size - 1 ) {
            $fh->seek( $pos + $self->global_offset, 0 ) || die $!;
            $fh->read( my $offset, $OffsetSize ) || die $!;
            $data[$i]->[2] = unpack( 'N', $offset );
            $pos += $OffsetSize;
        }

        foreach my $data (@data) {
            my ( $sha1, $crc, $offset ) = @$data;
            if ( $sha1 eq $want_sha1 ) {
                return $self->unpack_object($offset);
            }
        }
        return;

    }
}

sub unpack_object {
    my ( $self, $offset ) = @_;
    my $obj_offset = $offset;
    my $fh         = $self->open_pack;

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
        ( $type, $size, my $content )
            = $self->unpack_deltified( $fh, $type, $offset, $obj_offset,
            $size );
        return ( $type, $size, $content );

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

sub unpack_deltified {
    my ( $self, $fh, $type, $offset, $obj_offset, $size ) = @_;

    my $base;

    $fh->seek( $offset, 0 ) || die $!;
    $fh->read( my $sha1, $SHA1Size ) || die $!;
    $sha1 = unpack( 'H*', $sha1 );

    if ( $type eq 'ofs_delta' ) {
        die 'ofs_delta unimplemented';
    } else {
        ( $type, undef, $base ) = $self->get_object($sha1);
        $offset += $SHA1Size;

    }

    my $delta = $self->read_compressed( $fh, $offset, $size );
    my $new = $self->patch_delta( $base, $delta );

    return ( $type, length($new), $new );
}

sub patch_delta {
    my ( $self, $base, $delta ) = @_;
    my ( $src_size, $pos ) = $self->patch_delta_header_size( $delta, 0 );
    if ( $src_size != length($base) ) {
        confess "invalid delta data";
    }

    my ( $dest_size, $pos ) = $self->patch_delta_header_size( $delta, $pos );
    my $dest = "";

    while ( $pos < length($delta) ) {
        my $c = substr( $delta, $pos, 1 );
        $c = unpack( 'C', $c );
        $pos++;
        if ( ( $c & 0x80 ) != 0 ) {

            my $cp_off  = 0;
            my $cp_size = 0;
            $cp_off = unpack( 'C', substr( $delta, $pos++, 1 ) )
                if ( $c & 0x01 ) != 0;
            $cp_off |= unpack( 'C', substr( $delta, $pos++, 1 ) ) << 8
                if ( $c & 0x02 ) != 0;
            $cp_off |= unpack( 'C', substr( $delta, $pos++, 1 ) ) << 16
                if ( $c & 0x04 ) != 0;
            $cp_off |= unpack( 'C', substr( $delta, $pos++, 1 ) ) << 24
                if ( $c & 0x08 ) != 0;
            $cp_size = unpack( 'C', substr( $delta, $pos++, 1 ) )
                if ( $c & 0x10 ) != 0;
            $cp_size |= unpack( 'C', substr( $delta, $pos++, 1 ) ) << 8
                if ( $c & 0x20 ) != 0;
            $cp_size |= unpack( 'C', substr( $delta, $pos++, 1 ) ) << 16
                if ( $c & 0x40 ) != 0;
            $cp_size = 0x10000 if $cp_size == 0;

            $dest .= substr( $base, $cp_off, $cp_size );
        } elsif ( $c != 0 ) {
            $dest .= substr( $delta, $pos, $c );
            $pos += $c;
        } else {
            confess 'invalid delta data';
        }
    }

    if ( length($dest) != $dest_size ) {
        confess 'invalid delta data';
    }
    return $dest;
}

sub patch_delta_header_size {
    my ( $self, $delta, $pos ) = @_;

    my $size  = 0;
    my $shift = 0;
    while (1) {

        my $c = substr( $delta, $pos, 1 );
        unless ( defined $c ) {
            confess 'invalid delta header';
        }
        $c = unpack( 'C', $c );

        $pos++;
        $size |= ( $c & 0x7f ) << $shift;
        $shift += 7;
        last if ( $c & 0x80 ) == 0;
    }
    return ( $size, $pos );
}
1;
