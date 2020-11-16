#!/usr/bin/perl -w
#-----------------------------
# download the following standalone program
#!/usr/bin/perl -w
# udpmsg - send a message to the udpquotd server

use IO::Socket;
use strict;

my ( $sock, $server_host, $msg, $port, $ipaddr, $hishost, $MAXLEN, $PORTNO, $TIMEOUT );

$MAXLEN  = 1024;
$PORTNO  = 5151;
$TIMEOUT = 5;

$server_host = "localhost";
$msg         = "Test_";
my $i = 1;

$sock = IO::Socket::INET->new(
    Proto    => 'udp',
    #Type     => SOCK_DRAM,
    PeerPort => $PORTNO,
    PeerAddr => $server_host
) or die "Creating socket: $!\n";

while (1) {
    my $m = "Test_" . $i++;

    $sock->send($m) or die "send: $!";

    eval {
        local $SIG{ALRM} = sub { die "alarm time out" };
        alarm $TIMEOUT;
        $sock->recv( $msg, $MAXLEN ) or die "recv: $!";
        alarm 0;
        1;    # return value from eval on normalcy
    } or die "recv from $server_host timed out after $TIMEOUT seconds.\n";

    ( $port, $ipaddr ) = sockaddr_in( $sock->peername );
    $hishost = gethostbyaddr( $ipaddr, AF_INET );
    print "Server $hishost responded ``$msg''\n";
    sleep(10);
}

