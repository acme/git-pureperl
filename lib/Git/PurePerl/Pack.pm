package Git::PurePerl::Pack;
use Moose;
use MooseX::StrictConstructor;
use MooseX::Types::Path::Class;
use Compress::Raw::Zlib;
use IO::File;

has 'filename' =>
    ( is => 'ro', isa => 'Path::Class::File', required => 1, coerce => 1 );
has 'fh' => ( is => 'rw', isa => 'IO::File', required => 0 );

__PACKAGE__->meta->make_immutable;

my @TYPES = ( 'none', 'commit', 'tree', 'blob', 'tag', '', 'ofs_delta',
    'ref_delta' );
my $OBJ_NONE      = 0;
my $OBJ_COMMIT    = 1;
my $OBJ_TREE      = 2;
my $OBJ_BLOB      = 3;
my $OBJ_TAG       = 4;
my $OBJ_OFS_DELTA = 6;
my $OBJ_REF_DELTA = 7;

my $SHA1Size = 20;

sub BUILD {
    my $self = shift;
    my $fh = IO::File->new( $self->filename ) || confess($!);
    $self->fh($fh);
}

sub all_sha1s {
    my ( $self, $want_sha1 ) = @_;
    return Data::Stream::Bulk::Array->new(
        array => [ $self->index->all_sha1s ] );
}

sub unpack_object {
    my ( $self, $offset ) = @_;
    my $obj_offset = $offset;
    my $fh         = $self->fh;

    $fh->seek( $offset, 0 ) || die "Error seeking in pack: $!";
    $fh->read( my $c, 1 ) || die "Error reading from pack: $!";
    $c = unpack( 'C', $c ) || die $!;

    my $size        = ( $c & 0xf );
    my $type_number = ( $c >> 4 ) & 7;
    my $type = $TYPES[$type_number] || confess "invalid type $type_number";

    my $shift = 4;
    $offset++;

    while ( ( $c & 0x80 ) != 0 ) {
        $fh->read( $c, 1 ) || die $!;
        $c = unpack( 'C', $c ) || die $!;
        $size |= ( ( $c & 0x7f ) << $shift );
        $shift  += 7;
        $offset += 1;
    }

    if ( $type eq 'ofs_delta' || $type eq 'ref_delta' ) {
        ( $type, $size, my $content )
            = $self->unpack_deltified( $type, $offset, $obj_offset, $size );
        return ( $type, $size, $content );

    } elsif ( $type eq 'commit'
        || $type eq 'tree'
        || $type eq 'blob'
        || $type eq 'tag' )
    {
        my $content = $self->read_compressed( $offset, $size );
        return ( $type, $size, $content );
    } else {
        confess "invalid type $type";
    }
}

sub read_compressed {
    my ( $self, $offset, $size ) = @_;
    my $fh = $self->fh;

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

    $fh->seek( $offset + $deflate->total_in, 0 ) || die $!;
    return $out;
}

sub unpack_deltified {
    my ( $self, $type, $offset, $obj_offset, $size ) = @_;
    my $fh = $self->fh;

    my $base;

    $fh->seek( $offset, 0 ) || die $!;
    $fh->read( my $data, $SHA1Size ) || die $!;
    my $sha1 = unpack( 'H*', $data );

    if ( $type eq 'ofs_delta' ) {
        my $i           = 0;
        my $c           = unpack( 'C', substr( $data, $i, 1 ) );
        my $base_offset = $c & 0x7f;

        while ( ( $c & 0x80 ) != 0 ) {
            $c = unpack( 'C', substr( $data, ++$i, 1 ) );
            $base_offset++;
            $base_offset <<= 7;
            $base_offset |= $c & 0x7f;
        }
        $base_offset = $obj_offset - $base_offset;
        $offset += $i + 1;

        ( $type, undef, $base ) = $self->unpack_object($base_offset);
    } else {
        ( $type, undef, $base ) = $self->get_object($sha1);
        $offset += $SHA1Size;

    }

    my $delta = $self->read_compressed( $offset, $size );
    my $new = $self->patch_delta( $base, $delta );

    return ( $type, length($new), $new );
}

sub patch_delta {
    my ( $self, $base, $delta ) = @_;

    my ( $src_size, $pos ) = $self->patch_delta_header_size( $delta, 0 );
    if ( $src_size != length($base) ) {
        confess "invalid delta data";
    }

    ( my $dest_size, $pos ) = $self->patch_delta_header_size( $delta, $pos );
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
