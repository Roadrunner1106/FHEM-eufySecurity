#!/usr/bin/perl -w

use IO::Socket;
use Data::Dumper qw(Dumper);

use constant RequestMessageType => {
    LOOKUP_WITH_DSK => "\xf1\x26",
    LOCAL_LOOKUP    => "\xf1\x30",
    CHECK_CAM       => "\xf1\x41",
    PING            => "\xf1\xe0",
    PONG            => "\xf1\xe1",
    DATA            => "\xf1\xd0",
    ACK             => "\xf1\xd1"
};
use constant ResponseMessageType => {
    STUN              => "\xf1\x01",
    LOOKUP_RESP       => "\xf1\x21",
    LOOKUP_ADDR       => "\xf1\x40",
    LOCAL_LOOKUP_RESP => "\xf1\x41",
    END               => "\xf1\xf0",
    PONG              => "\xf1\xe1",
    PING              => "\xf1\xe0",
    CAM_ID            => "\xf1\x42",
    ACK               => "\xf1\xd1",
    DATA              => "\xf1\xd0"
};
use constant MAGIC_WORD => 'XZYH';

sub lookupStation($$$);
sub p2p_connect($$);
sub sendMessage($$$);
sub sendCommandWithInt($$$$);

my $dsk_key        = '';
my $p2p_did        = 'HXEUCAM-058469-EPSJP';
my $station_serial = 'T8010P2320270E8D';
my $station_ip     = '192.168.1.59';
my $action_user_id = '43fd657bdc5d823a771836123e10d6b1f4a162d3';

my $hash = {
    P2P => {
        $station_serial => {
            p2p_did        => $p2p_did,
            action_user_id => $action_user_id
        }
    }
};

# Send Local Lookup Request to the station and determine port for further communication
print "Send LOCAL_LOOKUP Request\n";
if ( lookupStation( $hash, $station_serial, $station_ip ) ) {
    print "found local station\n";

    # connect to station
    if ( p2p_connect( $hash, $station_serial ) ) {
        print "connect to station $station_serial\n";

        # CMD_SET_ARMING   0 => away 1 => home, 2 => schedule, 63 => disarmed
        sendCommandWithInt( $hash, $station_serial, 1224, 1 );
    }

}

1;

# lookup for station in local network
sub lookupStation($$$) {
    my ( $hash, $station_sn, $local_ip ) = @_;

    my $local_port         = 32108;
    my $addressTimeoutInMs = 3 * 1000;
    my $buffer;

    my $sock = IO::Socket::INET->new(
        PeerAddr => $station_ip,
        PeerPort => $local_port,

        #ReusAddr  => 1,
        ReusePort => 1,

        #Type      => SOCK_DGRAM,
        Proto => 'udp'
    );

    if ( !$sock ) {
        print "failed create socket\n";
        return 0;
    }

    my $recvsock = IO::Socket::INET->new(
        Proto     => 'udp',
        LocalPort => $sock->sockport(),
        ReusAddr  => 1,
        ReusePort => 1,
        Timeout   => 3
    );

    if ( !$recvsock ) {
        print "failed create recvSocket\n";
        return 0;
    }

    my $payload = "\x00\x00";
    sendMessage( $sock, "\xf1\x30", $payload );
    $sock->close();

    $recvsock->recv( $buffer, 1024 );
    if ( hasHeader( $buffer, ResponseMessageType->{LOCAL_LOOKUP_RESP} ) ) {
        $hash->{P2P}{$station_sn}{p2p_did_hex} = substr( $buffer, 4, 17 );
    }

    print logResponseMessage($buffer);

    $local_port = $recvsock->peerport;
    $recvsock->close();

    $hash->{P2P}{$station_sn}{station_ip}   = $local_ip;
    $hash->{P2P}{$station_sn}{station_port} = $local_port;
    return 1;
}

# Connet to Station
sub p2p_connect($$) {
    my $hash       = shift;
    my $station_sn = shift;
    my $buffer;

    # Initialize a few variables for the connection
    $hash->{P2P}{$station_sn}{timeout}   = 3;
    $hash->{P2P}{$station_sn}{connect}   = 0;
    $hash->{P2P}{$station_sn}{seqNumber} = 0;

    print "p2p_connect to ip:port => " . $hash->{P2P}{$station_sn}{station_ip} . ":" . $hash->{P2P}{$station_sn}{station_port} . "\n";

    my $sock = IO::Socket::INET->new(
        PeerAddr => $hash->{P2P}{$station_sn}{station_ip},
        PeerPort => $hash->{P2P}{$station_sn}{station_port},

        #ReusAddr  => 1,
        ReusePort => 1,

        #Type      => SOCK_DGRAM,
        Proto => 'udp',
    );

    if ( !$sock ) {
        print "failed create socket\n";
        return 0;
    }

    #     my $recvsock = IO::Socket::INET->new(
    #         Proto     => 'udp',
    #         LocalPort => $sock->sockport(),
    #         ReusAddr  => 1,
    #         ReusePort => 1,
    #         Timeout   => 3
    #     );
    #
    #     if ( !$recvsock ) {
    #         print "failed create recvSocket\n";
    # $sock->close();
    #         return 0;
    #     }

    #print Dumper($recvsock);

    sendMessage( $sock, RequestMessageType->{CHECK_CAM}, $hash->{P2P}{$station_sn}{p2p_did_hex} . "\x00\x00\x00\x00\x00\x00" );

    #$sock->close();

    print "p2p_connect send finished. Wait for CAM_ID Response\n";

    $sock->recv( $buffer, 1024 );
    print logResponseMessage($buffer);

    #$recvsock->close();
    $hash->{P2P}{$station_sn}{connect} = 1;
    $hash->{P2P}{$station_sn}{socket}  = $sock;

    return 1;
}

sub sendCommandWithInt($$$$) {
    my ( $hash, $station_sn, $cmd_type, $value ) = @_;

    # Entspricht Funktion buildIntCommandPayload(value, this.actor) aus payload.utils.ts
    my $payload = "\x84\x00";
    $payload .= "\x00\x00\x01\x00\xff\x00\x00\x00";
    $payload .= pack( 'c', $value );                                       # Value for comannd CMD_SET_ARMING
    $payload .= "\x00\x00\x00";
    $payload .= pack( 'A*', $hash->{P2P}{$station_sn}{action_user_id} );
    $payload .= "\x00" x 88;

    #print "payload [".unpack('H*',$payload)."] len:".length($payload)."\n";

    # Enspricht Funktion sendCommand aus device-client.service.ts
    my $seqNr = $hash->{P2P}{$station_sn}{seqNumber}++;

    # buildCommandHeader(msgSeqNumber, commandType);
    my $cmdHeader = "\xd1\x00" . int2BE($seqNr).MAGIC_WORD.int2LE($cmd_type);
	my $data = $cmdHeader.$payload;

	sendMessage($hash->{P2P}{$station_sn}{socket}, RequestMessageType->{DATA}, $data)
}

sub hasHeader($$) {
    my ( $msg, $type ) = @_;
    return substr( $msg, 0, 2 ) eq $type;
}

sub sendMessage($$$) {
    my ( $sock, $type, $payload ) = @_;

    my $payload_len = int2BE( length($payload) );
    my $message     = $type . $payload_len . $payload;

    $sock->send($message);

    my $hex = unpack( 'H*', $message );
    print "send message [$hex]\n";
}

# convert integer in two bytes, low byte first (Little-Endian-Format)
sub int2LE($) {
    my $value = shift;
    return pack( 'CC', $value % 256, int( $value / 256 ) );
}

# convert integer in two bytes, high byte first (Big-Endian-Format)
sub int2BE($) {
    my $value = shift;
    return pack( 'CC', int( $value / 256 ), $value % 256 );
}

sub logResponseMessage($) {
    my $msg     = shift;
    my $msg_str = '';

    $msg_str = "Receive Message [$msg] => ";
    my $cmd = substr( $msg, 0, 2 );

    #   if ( $cmd eq ResponseMessageType->{LOCAL_LOOKUP_RESP} ) {
    if ( hasHeader( $msg, ResponseMessageType->{LOCAL_LOOKUP_RESP} ) ) {
        $msg_str .= "Msg-Type: LOCAL_LOOKUP_RESP ";
        my ( undef, $len_h, $len_l, $p2p_did1, undef, $p2p_did2_h, $p2p_did2_l, $p2p_did3 ) = unpack( 'H4CCA7H6CCA6', $msg );
        $msg_str .= "Payload len: " . ( $len_h * 256 + $len_l ) . " ";
        $msg_str .= "P2P_did: " . $p2p_did1 . "-" . substr( "000000" . ( $p2p_did2_h * 256 + $p2p_did2_l ), -6 ) . "-" . $p2p_did3;
    }
    elsif ( hasHeader( $msg, ResponseMessageType->{CAM_ID} ) ) {
        $msg_str .= "Msg-Type: CAM_ID Response ";
        my ( undef, $len_h, $len_l, $p2p_did1, undef, $p2p_did2_h, $p2p_did2_l, $p2p_did3 ) = unpack( 'H4CCA7H6CCA6', $msg );
        $msg_str .= "Payload len: " . ( $len_h * 256 + $len_l ) . " ";
        $msg_str .= "P2P_did: " . $p2p_did1 . "-" . substr( "000000" . ( $p2p_did2_h * 256 + $p2p_did2_l ), -6 ) . "-" . $p2p_did3;
    }
    else {
        $msg_str .= "Msg-Type: Unknown Response Message Type: " . unpack( 'H4', $msg );
    }

    $msg_str .= "\n";
    return $msg_str;
}
