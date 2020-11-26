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
$TIMEOUT = 1;

$server_host = "localhost";
$msg         = "Test_";
my $i = 1;

$sock = IO::Socket::INET->new(
    Proto => 'udp',

    #Type     => SOCK_DRAM,
    PeerPort => $PORTNO,
    PeerAddr => $server_host
) or die "Creating socket: $!\n";

my $is_connect = 1;

while ($is_connect) {
    my $m = "Test_" . $i++;

    $sock->send($m) or die "send: $!";

    eval {
        local $SIG{ALRM} = sub { die "timeout\n" };
        alarm $TIMEOUT;
        $sock->recv( $msg, $MAXLEN ) or die "recv: $!";
        alarm 0;
    };
	print @_."\n";
    if (@_) {
        print "Lost connection! Quit client!\n";
        $is_connect = 0;
    }
    else {
        ( $port, $ipaddr ) = sockaddr_in( $sock->peername );
        $hishost = gethostbyaddr( $ipaddr, AF_INET );
        print "Server $hishost responded ``$msg''\n";
        sleep(3);
    }
}

