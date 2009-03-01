package Git::PurePerl::Protocol;
use Moose;
use MooseX::StrictConstructor;
use Moose::Util::TypeConstraints;

has 'hostname' => ( is => 'ro', isa => 'Str', required => 1 );
has 'port'    => ( is => 'ro', isa => 'Int', required => 0, default => 9418 );
has 'project' => ( is => 'ro', isa => 'Str', required => 1 );
has 'socket' => ( is => 'rw', isa => 'IO::Socket', required => 0 );

sub connect {
    my $self = shift;

    my $socket = IO::Socket::INET->new(
        PeerAddr => $self->hostname,
        PeerPort => $self->port,
        Proto    => 'tcp'
    ) || die $!;
    $socket->autoflush(1) || die $!;
    $self->socket($socket);

    $self->send_line( "git-upload-pack "
            . $self->project
            . "\0host="
            . $self->hostname
            . "\0" );

    my %sha1s;
    while ( my $line = $self->read_line() ) {

        # warn "S $line";
        my ( $sha1, $name ) = $line =~ /^([a-z0-9]+) ([^\0\n]+)/;

        #use YAML; warn Dump $line;
        $sha1s{$name} = $sha1;
    }
    return \%sha1s;
}

sub fetch_pack {
    my ( $self, $sha1 ) = @_;
    $self->send_line("want $sha1 side-band-64k\n");

#send_line(
#    "want 0c7b3d23c0f821e58cd20e60d5e63f5ed12ef391 multi_ack side-band-64k ofs-delta\n"
#);
    $self->send_line('');
    $self->send_line('done');

    my $pack;

    while ( my $line = $self->read_line() ) {
        if ( $line =~ s/^\x02// ) {
            print $line;
        } elsif ( $line =~ /^NAK\n/ ) {
        } elsif ( $line =~ s/^\x01// ) {
            $pack .= $line;
        } else {
            die "Unknown line: $line";
        }

        #say "s $line";
    }
    return $pack;
}

sub send_line {
    my ( $self, $line ) = @_;
    my $length = length($line);
    if ( $length == 0 ) {
    } else {
        $length += 4;
    }

    #warn "length $length";
    my $prefix = sprintf( "%04X", $length );
    my $text = $prefix . $line;

    # warn "$text";
    $self->socket->print($text) || die $!;
}

sub read_line {
    my $self   = shift;
    my $socket = $self->socket;

    my $ret = $socket->read( my $prefix, 4 );
    if ( not defined $ret ) {
        die "error: $!";
    } elsif ( $ret == 0 ) {
        die "EOF";
    }

    return if $prefix eq '0000';

    # warn "read prefix [$prefix]";

    my $len = 0;
    foreach my $n ( 0 .. 3 ) {
        my $c = substr( $prefix, $n, 1 );
        $len <<= 4;

        if ( $c ge '0' && $c le '9' ) {
            $len += ord($c) - ord('0');
        } elsif ( $c ge 'a' && $c le 'f' ) {
            $len += ord($c) - ord('a') + 10;
        } elsif ( $c ge 'A' && $c le 'F' ) {
            $len += ord($c) - ord('A') + 10;
        }
    }

    #say "len $len";
    $socket->read( my $data, $len - 4 ) || die $!;
    return $data;
}

1;
