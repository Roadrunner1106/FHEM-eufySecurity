#!/usr/bin/perl -w

use IO::Socket;

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

sub lookup($);

my $dsk_key        = '';
my $p2p_did        = 'HXEUCAM-058469-EPSJP';
my $station_serial = 'T8010P2320270E8D';
my $station_ip     = '192.168.1.59';
my $action_user_id = '43fd657bdc5d823a771836123e10d6b1f4a162d3';

my ( $ip, $port ) = lookup($station_ip);
print "found station ip:$ip port:$port\n";

# lookup for station in local network
# Parameter: local ip_addresss
# Return: ip_address, port
sub lookup($) {
    my $local_ip           = shift;
    my $local_port         = 32108;
    my $addressTimeoutInMs = 3 * 1000;
    my $buffer;

    my $sock = IO::Socket::INET->new(
        PeerAddr  => $station_ip,
        PeerPort  => $local_port,
        ReusAddr  => 1,
        ReusePort => 1,
        Type      => SOCK_DGRAM,
        Proto     => 'udp'
    ) or die "socket: $@";

    my $recsock = IO::Socket::INET->new(
        Proto     => 'udp',
        LocalPort => $sock->sockport(),
        ReusAddr  => 1,
        ReusePort => 1,
    ) or die "socket: $@";

    # set receive timeout to 500msecs second (format is: secs, microsecs)
    #if (!$recvsock->setsockopt(SOL_SOCKET, SO_RCVTIMEO, pack('l!l!', 0, 500*1000))) {
    #	print "could not set SO_RCVTIMEO on recvSocket");
    #	return (undef,undef);
    #}

    my $payload = "\x00\x00";
    sendMessage( $sock, $local_ip, $local_port, "\xf1\x30", $payload );
    $sock->close();

    $recsock->recv( $buffer, 1024 );
    print "receive message: [$buffer]\n";
    $local_port = $recsock->peerport;
    $recsock->close();

    return ( $local_ip, $local_port );
}

sub sendMessage($$$$$) {
    my ( $sock, $ip, $port, $type, $payload ) = @_;

    #my $payload_len = pack('H*',int((length($payload)/256))).pack('H*',length($payload)%256);
    my $payload_len = "\x00\x02";
    my $message     = $type . $payload_len . $payload;

    my $hex = unpack( 'H*', $message );

    my $sent = $sock->send($message);
    print "send to ip:port [message] $ip:$port [$hex]\n";
}

sub logReceiveMessage($) {
    my $msg     = shift;
    my $msg_str = '';

}
