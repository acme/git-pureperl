package Git::PurePerl::Pack;
use Moose;
use MooseX::StrictConstructor;
use MooseX::Types::Path::Class;
use Compress::Raw::Zlib;
use IO::File;

has 'filename' =>
    ( is => 'ro', isa => 'Path::Class::File', required => 1, coerce => 1 );
has 'index_filename' =>
    ( is => 'rw', isa => 'Path::Class::File', required => 0, coerce => 1 );
has 'index' =>
    ( is => 'rw', isa => 'Git::PurePerl::PackIndex', required => 0 );
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

    my $filename = $self->filename;
    my $fh = IO::File->new($filename) || confess($!);
    $self->fh($fh);

    my $index_filename = $filename;
    $index_filename =~ s/\.pack/.idx/;
    $self->index_filename($index_filename);

    if ( -f $index_filename ) {
        my $index_fh = IO::File->new($index_filename) || confess($!);
        $index_fh->read( my $signature, 4 );
        $index_fh->read( my $version,   4 );
        $version = unpack( 'N', $version );
        $index_fh->close;

        if ( $signature eq "\377tOc" ) {
            if ( $version == 2 ) {
                $self->index(
                    Git::PurePerl::PackIndex::Version2->new(
                        filename => $index_filename
                    )
                );
            } else {
                confess("Unknown version");
            }
        } else {
            $self->index(
                Git::PurePerl::PackIndex::Version1->new(
                    filename => $index_filename
                )
            );
        }
    }
}

sub all_sha1s {
    my ( $self, $want_sha1 ) = @_;
    return Data::Stream::Bulk::Array->new(
        array => [ $self->index->all_sha1s ] );
}

sub get_object {
    my ( $self, $want_sha1 ) = @_;
    my $offset = $self->index->get_object_offset($want_sha1);
    return unless $offset;
    return $self->unpack_object($offset);
}

sub unpack_object {
    my ( $self, $offset ) = @_;
    my $obj_offset = $offset;
    my $fh         = $self->fh;

    # warn "unpack_object $offset";

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

    # warn "read_compressed $offset, $size";

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

    #warn "total in = " . $deflate->total_in;
    #warn "total out = " . $deflate->total_out;
    #warn "seeking to " . ( $offset + $deflate->total_in );
    $fh->seek( $offset + $deflate->total_in, 0 ) || die $!;
    return $out;
}

sub unpack_deltified {
    my ( $self, $type, $offset, $obj_offset, $size ) = @_;
    my $fh = $self->fh;

    # warn "unpack_deltified $type $offset, $obj_offset, $size";

    my $base;

    $fh->seek( $offset, 0 ) || die $!;
    $fh->read( my $data, $SHA1Size ) || die $!;
    my $sha1 = unpack( 'H*', $data );

    #warn "$sha1";

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

    #warn "patch_delta";
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

    #warn "patch_delta_header_size";

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

=for python

def write_pack_index_v1(filename, entries, pack_checksum):
    """Write a new pack index file.

    :param filename: The filename of the new pack index file.
    :param entries: List of tuples with object name (sha), offset_in_pack,  and
            crc32_checksum.
    :param pack_checksum: Checksum of the pack file.
    """
    f = open(filename, 'w')
    f = SHA1Writer(f)
    fan_out_table = defaultdict(lambda: 0)
    for (name, offset, entry_checksum) in entries:
        fan_out_table[ord(name[0])] += 1
    # Fan-out table
    for i in range(0x100):
        f.write(struct.pack(">L", fan_out_table[i]))
        fan_out_table[i+1] += fan_out_table[i]
    for (name, offset, entry_checksum) in entries:
        f.write(struct.pack(">L20s", offset, name))
    assert len(pack_checksum) == 20
    f.write(pack_checksum)
    f.close()

=cut

sub create_index {
    my ($self) = @_;
    my $index_filename = $self->index_filename;
    my $index_fh = IO::File->new("> $index_filename") || die $!;

    my $index_sha1 = Digest::SHA1->new;

    my $offsets = $self->create_index_offsets;
    my @fan_out_table;
    foreach my $sha1 ( sort keys %$offsets ) {
        my $offset = $offsets->{$sha1};
        my $slot = unpack( 'C', pack( 'H*', $sha1 ) );

        #warn "$sha1 = $offset = $slot\n";
        $fan_out_table[$slot]++;
    }
    foreach my $i ( 0 .. 255 ) {
        $index_fh->print( pack( 'N', $fan_out_table[$i] || 0 ) ) || die $!;
        $index_sha1->add( pack( 'N', $fan_out_table[$i] || 0 ) );
        $fan_out_table[ $i + 1 ] += $fan_out_table[$i] || 0;
    }
    foreach my $sha1 ( sort keys %$offsets ) {
        my $offset = $offsets->{$sha1};
        $index_fh->print( pack( 'N',  $offset ) ) || die $!;
        $index_sha1->add( pack( 'N',  $offset ) );
        $index_fh->print( pack( 'H*', $sha1 ) )   || die $!;
        $index_sha1->add( pack( 'H*', $sha1 ) );

    }

    # read the pack checksum from the end of the pack file
    my $size = -s $self->filename;
    my $fh   = $self->fh;
    $fh->seek( $size - 20, 0 ) || die $!;
    my $read = $fh->read( my $pack_sha1, 20 ) || die $!;

    $index_fh->print($pack_sha1) || die $!;
    $index_sha1->add($pack_sha1);
    $index_fh->print( $index_sha1->clone->digest ) || die $!;

    $index_fh->close() || die $!;
}

sub create_index_offsets {
    my ($self) = @_;
    my $fh = $self->fh;

    $fh->read( my $signature, 4 );
    $fh->read( my $version,   4 );
    $version = unpack( 'N', $version );
    $fh->read( my $objects, 4 );
    $objects = unpack( 'N', $objects );

    #warn "$signature / $version / $objects";

    my %offsets;
    foreach my $i ( 1 .. $objects ) {
        my $offset = $fh->tell || die "Error telling filehandle: $!";

        #warn "top offset $offset";

        #  $fh->seek($offset, 0) || die "Error seeking to $offset: $!";
        my $obj_offset = $offset;
        $fh->read( my $c, 1 ) || die "Error reading from pack: $!";
        $c = unpack( 'C', $c ) || die $!;
        $offset++;

        my $size        = ( $c & 0xf );
        my $type_number = ( $c >> 4 ) & 7;
        my $type        = $TYPES[$type_number]
            || confess
            "invalid type $type_number at offset $offset, size $size";

        my $shift = 4;

        while ( ( $c & 0x80 ) != 0 ) {
            $fh->read( $c, 1 ) || die $!;
            $c = unpack( 'C', $c ) || die $!;
            $offset++;
            $size |= ( ( $c & 0x7f ) << $shift );
            $shift += 7;
        }

        #warn "offset $obj_offset, type $type, size $size";
        my $content;

        if ( $type eq 'ofs_delta' || $type eq 'ref_delta' ) {
            ( $type, $size, $content )
                = $self->unpack_deltified_create( $type, $offset, $obj_offset,
                $size, \%offsets );

            #warn "$type / $size";

        } elsif ( $type eq 'commit'
            || $type eq 'tree'
            || $type eq 'blob'
            || $type eq 'tag' )
        {
            $content = $self->read_compressed( $offset, $size );

            #warn "$type / $size " . length($content);

        } else {
            confess "invalid type $type";
        }

        my $raw  = $type . ' ' . $size . "\0" . $content;
        my $sha1 = Digest::SHA1->new;
        $sha1->add($raw);
        my $sha1_hex = $sha1->hexdigest;

        #warn "$obj_offset / $type / $size / $sha1_hex";

# while we should really be creating an index, let's add the objects as loose instead
#        my $object = Git::PurePerl::NewObject->new(
#            kind    => $type,
#            size    => $size,
#            sha1    => $sha1_hex,
#            content => $content,
#        );
#        $git->loose->put_object($object);#
#
        $offsets{$sha1_hex} = $obj_offset;
    }

    #    foreach my $sha1 ( sort keys %offsets ) {
    #        my $offset = $offsets{$sha1};
    #        warn "$sha1 = $offset\n";
    #    }
    return \%offsets;
}

sub unpack_deltified_create {
    my ( $self, $type, $offset, $obj_offset, $size, $offsets ) = @_;
    my $fh = $self->fh;

    #warn "unpack_deltified_create $type $offset $obj_offset $size $offsets";
    my $base;

    $fh->seek( $offset, 0 ) || die $!;
    $fh->read( my $data, $SHA1Size ) || die $!;
    my $sha1 = unpack( 'H*', $data );
    my $offset_before = $fh->tell;

    #    warn "$sha1";

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

        ( $type, undef, $base )
            = $self->unpack_object_create( $base_offset, $offsets );
    } else {

        #        ( $type, undef, $base ) = $self->get_object($sha1);
        #warn "unpacking object at " . $offsets->{$sha1};
        ( $type, undef, $base )
            = $self->unpack_object_create( $offsets->{$sha1}, $offsets );
        $offset += $SHA1Size;

    }

    my $delta = $self->read_compressed( $offset, $size );
    my $offset_after = $fh->tell;

    #die "$offset_before ... $offset_after";
    my $new = $self->patch_delta( $base, $delta );

    return ( $type, length($new), $new );
}

sub unpack_object_create {
    my ( $self, $offset, $offsets ) = @_;
    my $obj_offset = $offset;
    my $fh         = $self->fh;

    #warn "unpack_object_create $offset $offsets";

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
            = $self->unpack_deltified_create( $type, $offset, $obj_offset,
            $size, $offsets );
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

1;
