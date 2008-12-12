package Git::PurePerl::PackIndex::Version2;
use Moose;
use MooseX::StrictConstructor;

extends 'Git::PurePerl::PackIndex';
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

sub global_offset {
    return 8;
}

sub all_sha1s {
    my ( $self, $want_sha1 ) = @_;
    my $fh = $self->fh;
    my @sha1s;
    my @data;

    my $pos = $OffsetStart;
    $fh->seek( $pos + $self->global_offset, 0 ) || die $!;
    foreach my $i ( 0 .. $self->size - 1 ) {
        $fh->read( my $sha1, $SHA1Size ) || die $!;
        $data[$i] = [ unpack( 'H*', $sha1 ), 0, 0 ];
        $pos += $SHA1Size;
    }
    $fh->seek( $pos + $self->global_offset, 0 ) || die $!;
    foreach my $i ( 0 .. $self->size - 1 ) {
        $fh->read( my $crc, $CrcSize ) || die $!;
        $data[$i]->[1] = unpack( 'H*', $crc );
        $pos += $CrcSize;
    }
    $fh->seek( $pos + $self->global_offset, 0 ) || die $!;
    foreach my $i ( 0 .. $self->size - 1 ) {
        $fh->read( my $offset, $OffsetSize ) || die $!;
        $data[$i]->[2] = unpack( 'N', $offset );
        $pos += $OffsetSize;
    }
    foreach my $data (@data) {
        my ( $sha1, $crc, $offset ) = @$data;
        push @sha1s, $sha1;
    }

    return @sha1s;
}

sub get_object_offset {
    my ( $self, $want_sha1 ) = @_;
    my @offsets = $self->offsets;
    my $fh      = $self->fh;

    my $slot = unpack( 'C', pack( 'H*', $want_sha1 ) );
    return unless defined $slot;

    my ( $first, $last ) = @offsets[ $slot, $slot + 1 ];

    while ( $first < $last ) {
        my $mid = int( ( $first + $last ) / 2 );

        $fh->seek( $self->global_offset + $OffsetStart + ( $mid * $SHA1Size ),
            0 )
            || die $!;
        $fh->read( my $data, $SHA1Size ) || die $!;
        my $midsha1 = unpack( 'H*', $data );
        if ( $midsha1 lt $want_sha1 ) {
            $first = $mid + 1;
        } elsif ( $midsha1 gt $want_sha1 ) {
            $last = $mid;
        } else {
            my $pos
                = $self->global_offset 
                + $OffsetStart
                + ( $self->size * ( $SHA1Size + $CrcSize ) )
                + ( $mid * $OffsetSize );
            $fh->seek( $pos, 0 ) || die $!;
            $fh->read( my $data, $OffsetSize ) || die $!;
            my $offset = unpack( 'N', $data );
            return $offset;
        }
    }
    return;
}

1;
