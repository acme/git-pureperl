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

    $self->send_line(
        "git-upload-pack " . $self->project . "\000host=localhost\000" );

    my %sha1s;
    while ( my $line = $self->read_line() ) {

        # warn "S $line";
        my ( $sha1, $name ) = $line =~ /^([a-z0-9]+) ([^\0\n]+)/;

        #use YAML; warn Dump $line;
        $sha1s{$name} = $sha1;
    }
    return \%sha1s;
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

    # warn "C $text";
    $self->socket->print($text) || die $!;
}

sub read_line {
    my $self   = shift;
    my $socket = $self->socket;

    $socket->read( my $prefix, 4 ) || die $!;
    return if $prefix eq '0000';

    #    say "read prefix [$prefix]";

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
