#
#  73_eufySecurity.pm
#

package main;

# Laden evtl. abhängiger Perl- bzw. FHEM-Hilfsmodule
use HttpUtils;
use JSON;
use Encode;
use utf8;
use IO::Socket;
use Data::Dumper qw(Dumper);

# eufy Security Device Typen
my %DeviceType = (
    0  => [ 'STATION',          'Home Base 2' ],
    1  => [ 'CAMERA',           'Camera' ],
    2  => [ 'SENSOR',           'Sensor' ],
    3  => [ 'FLOODLIGHT',       'Floodlight' ],
    4  => [ 'CAMERA_E',         'eufyCam E' ],
    5  => [ 'DOORBELL',         'Doorbell' ],
    7  => [ 'BATTERY_DOORBELL', 'Battery Doorbell' ],
    8  => [ 'CAMERA2C',         'eufyCam 2C' ],
    9  => [ 'CAMERA2',          'eufyCam 2' ],
    10 => [ 'MOTION_SENSOR',    'Motion Sesor' ],
    11 => [ 'KEYPAD',           'Keypad' ],
    30 => [ 'INDOOR_CAMERA',    'Indoor Cemera' ],
    31 => [ 'INDOOR_PT_CAMERA', 'Indoor PR Camera' ],
    50 => [ 'LOCK_BASIC',       'Lock Basic' ],
    51 => [ 'LOCK_ADVANCED',    'Lock Advanced' ],
    52 => [ 'LOCK_SIMPLE',      'Lock Simple' ]
);

# eufy Security Guard Mode
my %GuardMode = (
    0  => [ 'AWAY',       'Abwesend' ],
    1  => [ 'HOME',       'Zuhause' ],
    2  => [ 'SCHEDULE',   'Zeitplan' ],
    47 => [ 'GEOFENCING', 'Geofencing' ],
    63 => [ 'DISARMED',   'Deaktiviert' ]
);

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

# eufy Securiyt Parameter Keys
my %ParamKey = (
    1011 => [ 'CAMERA_PIR',                       '' ],
    1013 => [ 'CAMERA_IR_CUT',                    '' ],
    1133 => [ 'CAMERA_UPGRADE_NOW',               '' ],
    1134 => [ 'DEVICE_UPGRADE_NOW',               '' ],
    1142 => [ 'CAMERA_WIFI_RSSI',                 '' ],
    1176 => [ 'INTERNAL_IP',                      'Interne IP-Adresse' ],
    1204 => [ 'CAMERA_MOTION_ZONES',              '' ],
    1214 => [ 'WATERMARK_MODE',                   '1 - hide, 2 - show' ],
    1224 => [ 'GUARD_MODE',                       '0 - Away, 1 - Home, 63 - Disarmed, 2 - schedule' ],
    1230 => [ 'CAMERA_SPEAKER_VOLUME',            '' ],
    1249 => [ 'CAMERA_RECORD_CLIP_LENGTH',        'In seconds' ],
    1250 => [ 'CAMERA_RECORD_RETRIGGER_INTERVAL', 'In seconds' ],
    1252 => [ 'PUSH_MSG_MODE',                    '' ],
    1271 => [ 'SNOOZE_MODE',                      'The value is base64 encoded' ],
    1272 => [ 'FLOODLIGHT_MOTION_SENSITIVTY',     'The range is 1-5' ],
    1366 => [ 'CAMERA_RECORD_ENABLE_AUDIO',       '' ],
    1400 => [ 'FLOODLIGHT_MANUAL_SWITCH',         'The range is 22-100' ],
    1401 => [ 'FLOODLIGHT_MANUAL_BRIGHTNESS',     'The range is 22-100' ],
    1413 => [ 'FLOODLIGHT_SCHEDULE_BRIGHTNESS',   'The range is 22-100' ],
    2001 => [ 'OPEN_DEVICE',                      '' ],
    2002 => [ 'NIGHT_VISUAL',                     '' ],
    2003 => [ 'VOLUME',                           '' ],
    2004 => [ 'DETECT_MODE',                      '' ],
    2005 => [ 'DETECT_MOTION_SENSITIVE',          '' ],
    2006 => [ 'DETECT_ZONE',                      '' ],
    2007 => [ 'UN_DETECT_ZONE',                   '' ],
    2010 => [ 'SDCARD',                           '' ],
    2015 => [ 'CHIME_STATE',                      '' ],
    2022 => [ 'RINGING_VOLUME',                   '' ],
    2023 => [ 'DETECT_EXPOSURE',                  '' ],
    2027 => [ 'DETECT_SWITCH',                    '' ],
    2028 => [ 'DETECT_SCENARIO',                  '' ],
    2029 => [ 'DOORBELL_HDR',                     '' ],
    2030 => [ 'DOORBELL_IR_MODE',                 '' ],
    2031 => [ 'DOORBELL_VIDEO_QUALITY',           '' ],
    2032 => [ 'DOORBELL_BRIGHTNESS',              '' ],
    2033 => [ 'DOORBELL_DISTORTION',              '' ],
    2034 => [ 'DOORBELL_RECORD_QUALITY',          '' ],
    2035 => [ 'DOORBELL_MOTION_NOTIFICATION',     '' ],
    2036 => [ 'DOORBELL_NOTIFICATION_OPEN',       '' ],
    2037 => [ 'DOORBELL_SNOOZE_START_TIME',       '' ],
    2038 => [ 'DOORBELL_NOTIFICATION_JUMP_MODE',  '' ],
    2039 => [ 'DOORBELL_LED_NIGHT_MODE',          '' ],
    2040 => [ 'DOORBELL_RING_RECORD',             '' ],
    2041 => [ 'DOORBELL_MOTION_ADVANCE_OPTION',   '' ],
    2042 => [ 'DOORBELL_AUDIO_RECODE',            '' ],
);

# Base URL for Web-API
#my $BaseURL = 'https://mysecurity.eufylife.com/apieu/v1/';
my $BaseURL = 'https://security-app-eu.eufylife.com/v1/';

# eufySecurity Modulfunktionen

sub eufySecurity_Initialize($) {
    my ($hash) = @_;

    $hash->{DefFn}      = "eufySecurity_Define";
    $hash->{UndefFn}    = "eufySecurity_Undef";
    $hash->{DeleteFn}   = "eufySecurity_Delete";
    $hash->{ShutdownFn} = "eufySecurity_Shutdown";
    $hash->{RenameFn}   = "eufySecurity_Rename";
    $hash->{SetFn}      = "eufySecurity_Set";
    $hash->{GetFn}      = "eufySecurity_Get";
    $hash->{ReadFn}     = "eufySecurity_Read";

    # Noch nicht implementierte Funktionen auskommentiert
    #$hash->{AttrFn}   = "eufySecurity_Attr";
    #$hash->{ReadyFn}              = "eufySecurity_Ready";
    #$hash->{NotifyFn}             = "eufySecurity_Notify";
    #$hash->{DelayedShutdownFn}    = "eufySecurity_ DelayedShutdown";

    # Funktionen für zweistufiges Modulkonzept
    $hash->{WriteFn}       = "eufySecurity_Write";
    $hash->{FingerprintFn} = "eufySecurity_Fingerprint";
    $hash->{Clients}       = "eufyStation:eufyCamera";

    # Aufbau der Nachricht an die logischen Module
    # <device_type>:<device_name>:<cmd>[:<args>]
    #
    # <device_type> => numerisch (z.B. 9 für eufyCam 2)
    # <device_name> => Name des Device in FHEM. Format
    #                  Format: <moduld_name>_<device_sn>
    #                  z.B. eufyCamera_T8114P0220272D96
    # <cmd>.        => Kommando an logisches Modul z.B. UPDATE
	# <args>.       => optional weitere Argumente duch einen Doppelpunkt getrennt (abhängig von <cmd>)
    $hash->{MatchList} = {
        "1:eufyCamera"  => "^(1|7|8|9|30):.*",
        "2:eufyStation" => "^0:.*"
    };

    $hash->{AttrList} = 'mail ' . 'timeout ' . 'eufySecurity-API-URL' . $readingFnAttributes;
}

# define eufySecurity_<device_sn> eufySecurity <device_type> <device_sn>
sub eufySecurity_Define($$) {
    my ( $hash, $def ) = @_;
    my @param = split( '[ \t]+', $def );

    return 'too few parameters: define <NAME> eufySecurity'
      if ( int(@param) < 2 );

    my $name = $param[0];

    # Device ggf. den Raum eufySecurity zuweisen
    CommandAttr( undef, $name . ' room eufySecurity' )
      if ( AttrVal( $name, 'room', 'none' ) eq 'none' );

    # Default-Werte für schnellen API-Zugriff im $hash ablegen
    $hash->{connection}{auth_token}       = 'none';
    $hash->{connection}{token_expires_at} = '';
    $hash->{connection}{state}            = 'disconnect';
    $hash->{connection}{user_id}          = '';

    # Readings mit Default-Werten vorbesetzen
    readingsBeginUpdate($hash);
    readingsBulkUpdate( $hash, 'token',                $hash->{connection}{auth_token} );
    readingsBulkUpdate( $hash, 'token_expires',        $hash->{connection}{token_expires_at} );
    readingsBulkUpdate( $hash, 'state',                $hash->{connection}{state} );
    readingsBulkUpdate( $hash, 'devices',              '0' );
    readingsBulkUpdate( $hash, 'user_id',              $hash->{connection}{user_id} );
    readingsBulkUpdate( $hash, 'eufySecurity-API-URL', $BaseURL );
    readingsEndUpdate( $hash, 1 );

    Log3 $name, 3, "eufySecurity $name (Define) - defined";
    return undef;
}

sub eufySecurity_Undef($$) {
    my ( $hash, $name ) = @_;

    # TBD: Hier noch offene Verbindungne schliessen

    # Readings auf Default-Werte setzen
    readingsBeginUpdate($hash);
    readingsBulkUpdate( $hash, 'token',   'none' );
    readingsBulkUpdate( $hash, 'state',   'disconnect' );
    readingsBulkUpdate( $hash, 'devices', '0' );
    readingsEndUpdate( $hash, 1 );

    Log3 $name, 3, "eufySecurity $name (Undef) - undefined $name";

    return undef;
}

sub eufySecurity_Delete ($$) {
    my $hash = shift;
    my $name = shift;

    # delete saved password
    setKeyValue( $hash->{TYPE} . '_' . $name . '_password', undef );

    Log3 $name, 3, "eufySecurity $name (Delete) - deleted $name";

    return undef;
}

sub eufySecurity_Shutdown($) {
    my ($hash) = @_;

    #Todo Verbindung für alle offenen Sockets schliessen
}

sub eufySecurity_Rename($$) {
    my ( $new, $old ) = @_;

    Log3 $old, 3, "eufySecurity $old (Rename) - old name:$old  new name:$new";

    my $old_key     = "eufySecurity_" . $old . "_password";
    my $new_key     = "eufySecurity_" . $new . "_password";
    my $old_pwd_key = getUniqueId() . $old_key;
    my $new_pwd_key = getUniqueId() . $new_key;

    my ( $err, $enc_pwd ) = getKeyValue($old_key);

    return undef unless ( defined($enc_pwd) );

    my $pwd = decrypt_Password( $enc_pwd, $old_pwd_key );

    setKeyValue( $new_key, encrypt_Password( $pwd, $new_pwd_key ) );
    setKeyValue( $old_key, undef );
}

sub eufySecurity_Set($@) {
    my ( $hash, $name, $cmd, @args ) = @_;

    if ( $cmd eq "connect" ) {

        # E-Mail lesen und prüfen ob eine hinterlegt ist
        my $mail = AttrVal( $name, 'mail', '' );
        return 'Für connect muss eine E-Mail im Attribut mail hinterlegt sein!' if $mail eq '';

        my $key     = $hash->{TYPE} . "_" . $name . '_password';
        my $pwd_key = getUniqueId() . $key;
        my ( $err, $enc_pwd ) = getKeyValue($key);

        if ( defined $err ) {
            Log3 $name, 3, "eufySecurity $name (Get) no password set or reading error";
            return 'Für connect muss zuerst noch ein Passwort mit "set ' . $name . ' password GEHEIMESPASSWORT" hintelegt werden';
        }
        else {
            $pwd = decrypt_Password( $enc_pwd, $pwd_key );
            Log3 $name, 3, "eufySecurity $name (Set) - connect to eufySecurity";
            login2eufySecurity($hash);

        }
    }
    elsif ( $cmd eq "password" ) {
        Log3 $name, 3, "eufySecurity $name (Set) - set password for eufySecurity";
        if ( $args[0] ne '' ) {

            my $key     = $hash->{TYPE} . "_" . $name . '_password';
            my $pwd_key = getUniqueId() . $key;
            return setKeyValue( $key, encrypt_Password( $args[0], $pwd_key ) );
        }
        else {
            return 'Kein. Passwort angegeben set <name> password meinpasswort angegeben';
        }

    }
    elsif ( $cmd eq "del_password" ) {
        setKeyValue( $hash->{NAME} . "_password",                       undef );
        setKeyValue( $hash->{TYPE} . "_" . $hash->{NAME} . "_password", undef );
    }
    elsif ( $cmd eq "GuardMode" ) {
        #
    }
    else {
        return "Unknown argument $cmd, choose one of connect:noArg password GuardMode:Away,Home,Schedule,Geofencing,Disarmed del_password:noArg";
    }
}

sub eufySecurity_Get($$@) {
    my ( $hash, $name, $opt, @args ) = @_;

    return "\"get $name\" needs at least one argument" unless ( defined($opt) );

    Log3 $name, 3, "eufySecurity $name (Get) - cmd: $opt";

    if ( $opt eq "Hubs" ) {
        if ( isConnected($hash) ) {
            getHubs( $hash, '{"device_sn": "", "num": 100, "page": 0, "type": 0, "station_sn": ""}' );
        }
    }
    elsif ( $opt eq "Devices" ) {
        if ( isConnected($hash) ) {
            getDevices( $hash, '{"device_sn": "", "num": 100, "orderby": "", "page": 0, "station_sn": ""}' );
        }
    }
    elsif ( $opt eq "History" ) {
        if ( isConnected($hash) ) {
            my $param = {
                url      => $BaseURL . 'event/app/get_all_history_record',
                header   => "Content-Type: application/json\r\n" . "x-auth-token: " . $hash->{connection}{auth_token},
                data     => '{"device_sn": "","end_time": 0,"id": 0,"num": 100,"offset": -14400,"pullup": true,"shared": true,"start_time": 0,"storage": 0}',
                method   => "POST",
                hash     => $hash,
                loglevel => 5,
                timeout  => 10,
                callback => \&getHistoryCB
            };
            HttpUtils_NonblockingGet($param);
        }
    }
    elsif ( $opt eq "DEBUG_DskKey" ) {
        getDskKey( $hash, '{"station_sns": ["T8010P2320270E8D"]}' );
    }
    else {
        return "Unknown argument $opt, choose one of Hubs:noArg Devices:noArg History:noArg DEBUG_DskKey:noArg";
    }
}

sub eufySecurity_Read($) {
    my ($shash) = @_;    # ACHTUNG: Hier wird der Hash des Sockets übergeben und NICHT der Hash des Moduls!

    my $sock = $shash->{FH};

    # Hash des Moduls
    my $parent = $shash->{PARENT};
    my $hash   = $defs{$parent};
    my $name   = $hash->{NAME};

    my $buffer;
    $sock->recv( $buffer, 1024 );

    # if ( hasHeader( $buffer, ResponseMessageType->{PONG} ) ) {
    #
    #     # nothing todo
    #     # responing to a PING from our side
    #
    #     return;
    # }
    # elsif ( hasHeader( $buffer, ResponseMessageType->{PING} ) ) {
    #
    #     #Todo, we have to answer with a PONG
    #     Log3 $name, 3, "eufySecurity (Read) - receiver END-Message, close connection\n";
    #
    #     return;
    # }
    # elsif ( hasHeader( $buffer, ResponseMessageType->{END} ) ) {
    #
    #     #Todo
    #     #  - den Socket schliessen
    #     #  - Status Verbindung auf disconnect setzen
    #     #  - $shahs aus selectlist löschen
    # }
    # elsif ( hasHeader( $buffer, ResponseMessageType->{CAM_ID} ) ) {
    #
    #     # Answer from the device to a CAM_CHECK message
    #
    #     return;
    # }
    # elsif ( hasHeader( $buffer, ResponseMessageType->{ACK} ) ) {
    #
    #     #Todo noch weiter in device-client-service.ts analysieren und implementieren
    #     return;
    # }
    # elsif ( hasHeader( $buffer, ResponseMessageType->{DATA} ) )
    #
    #   #Todo noch weiter in device-client-service.ts analysieren und implementieren
    #   return;
    # else {
    #     #Todo Hier noch die Station ausgeben, von der das Telegram kommt
    #     Log3 $name, 3, "eufySecurity (Read) - unknown message type:" . unpack( 'H*', $buffer ) . "\n";
    # }
}

sub eufySecurity_Write ($$) {
    my ( $hash, $message, $address ) = @_;
    my $name = $hash->{NAME};
    my ( $device_type, $sn, $cmd, @args ) = split( /:/, $message );

    Log3 $name, 3, "eufySecurity $name (Write) - device_type:$device_type sn:$sn cmd:$cmd";

    if ( $cmd eq "UPDATE_DEVICE" ) {
        if ( isConnected($hash) ) {
            getDevices( $hash, '{"device_sn": "' . $sn . '", "num": 100, "orderby": "", "page": 0, "station_sn": ""}' );
        }
        return undef;
    }
    elsif ( $cmd eq "UPDATE_HUB" ) {
        if ( isConnected($hash) ) {
            getHubs( $hash, '{"device_sn": "", "num": 100, "page": 0, "type": 0, "station_sn": "' . $sn . '"}' );
        }
    }
    elsif ( $cmd eq "GET_DSK_KEY" ) {
        if ( isConnected($hash) ) {
            getDskKey( $hash, '{"station_sns": ["' . $sn . '"]}' );
        }
    }
    elsif ( $cmd eq "CONNECT_STATION" ) {
        Log3 $name, 3, "eufySecurity $name (Write) - connect to " . $args[0] . " p2p_did:" . $args[1] . " user_id:" . $args[2];
    }
    elsif ( $cmd eq "GUARD_MODE" ) {
        Log3 $name, 3, "eufySecurity $name (Write) - set Guard Mode to " . $args[0];
    }
    else {
        return "Unknown cmd $cmd";
    }
}

sub eufySecurity_Fingerprint($$) {
    my ( $io_name, $msg ) = @_;

    Log3 $name, 3, "eufySecurity (Fingerprint) - io_name: $io_name msg: $msg";

    #substr( $msg, 2, 2, "--" );    # entferne Empfangsadresse
    #substr( $msg, 4, 1, "-" );     # entferne Hop-Count

    return ( $io_name, $msg );
}

# ============================================================================
# Interne Hilfs-Funktionen
# ============================================================================

# ----------------------------------------------------------------------------
# Login to eufySecurity over Web-API
# ----------------------------------------------------------------------------
sub login2eufySecurity($) {
    my $hash = shift;
    my $name = $hash->{NAME};

    my $mail = AttrVal( $name, 'mail', '' );

    my $key     = $hash->{TYPE} . "_" . $name . '_password';
    my $pwd_key = getUniqueId() . $key;
    my ( $err, $enc_pwd ) = getKeyValue($key);

    if ( defined $err ) {
        Log3 $name, 3, "eufySecurity $name (login2eufySecurity) no password set or reading error";
        return 0;
    }
    else {
        $pwd = decrypt_Password( $enc_pwd, $pwd_key );
        Log3 $name, 3, "eufySecurity $name (login2eufySecurity) - Login to eufySecurity";

        my $param = {
            url    => $BaseURL . 'passport/login',
            header => "Content-Type: application/json",
            data   => '{"email": "' . $mail . '", "password": "' . $pwd . '"}',
            method => "POST"
        };

        Log3 $name, 3, "eufySecurity $name (login2eufySecurity) - url: " . $param->{url};

        my ( $err, $data ) = HttpUtils_BlockingGet($param);

        if ( $err eq "" ) {    # kein Fehler aufgetreten
            Log3 $name, 3, "eufySecurity (login2eufySecurity) - receive data: $data";

            ### Check if json can be parsed into hash
            eval {
                $json = decode_json( encode_utf8($data) );
                1;
            } or do {
                ### Log Entry for debugging purposes
                Log3 $name, 3, "eufySecurity (login2eufySecurity) - Error decode json $json";
                return 0;
            };

            if ( $json->{code} == 0 ) {
                $hash->{connection}{auth_token}       = $json->{data}{auth_token};
                $hash->{connection}{token_expires_at} = $json->{data}{token_expires_at};
                $hash->{connection}{user_id}          = $json->{data}{user_id};
                $hash->{connection}{state}            = "connect";

                readingsBeginUpdate($hash);
                readingsBulkUpdateIfChanged( $hash, 'eufySecurity-API-URL', $BaseURL,                                             1 );
                readingsBulkUpdateIfChanged( $hash, 'token',                $hash->{connection}{auth_token},                      1 );
                readingsBulkUpdateIfChanged( $hash, 'token_expires',        FmtDateTime( $hash->{connection}{token_expires_at} ), 1 );
                readingsBulkUpdateIfChanged( $hash, 'state',                $hash->{connection}{state},                           1 );
                readingsBulkUpdateIfChanged( $hash, 'user_id',              $hash->{connection}{user_id},                         1 );
                readingsEndUpdate( $hash, 1 );
            }
            else {
                Log3 $name, 3, "eufySecurity (login2eufySecurity) - eufySecurity error code: " . $json->{code} . " msg: " . $json->{msg};
                return 0;
            }
        }
        else {
            Log3 $name, 3, "eufySecurity (login2eufySecurity) - HttpUtils error $err";
            return 0;
        }
    }
    return 1;
}

# ----------------------------------------------------------------------------
# cchecking the connection and reconnect if nessesary
# ----------------------------------------------------------------------------
sub isConnected($) {
    my $hash = shift;
    my $name = $hash->{NAME};

    if ( ( $hash->{connection}{state} ne "connect" ) or ( $hash->{connection}{token_expires_at} < localtime() ) ) {
        Log3 $name, 3, "eufySecurity $name (isConnected) - reconnect to eufySecurity";
        return login2eufySecurity($hash);
    }
    else {
        Log3 $name, 3, "eufySecurity $name (isConnected) - allready connect to eufySecurity";
        return 1;
    }
}

# ----------------------------------------------------------------------------
# request list of stations
# ----------------------------------------------------------------------------
sub getHubs($$) {
    my ( $hash, $data ) = @_;
    my $name = $hash->{NAME};

    Log3 $name, 3, "eufySecurity $name (getHubs) - data: " . $data;

    my $param = {
        url      => $BaseURL . 'app/get_hub_list',
        header   => "Content-Type: application/json\r\n" . "x-auth-token: " . $hash->{connection}{auth_token},
        data     => $data,
        method   => "POST",
        hash     => $hash,
        loglevel => 5,
        timeout  => 10,
        callback => \&getHubsCB
    };
    Log3 $name, 3, "eufySecurity $name (GetHubs) - url: " . $param->{url};
    HttpUtils_NonblockingGet($param);
}

# ----------------------------------------------------------------------------
# Callback for function getHubs
# ----------------------------------------------------------------------------
sub getHubsCB($$$) {
    my ( $param, $err, $data ) = @_;
    my $json;
    my $hash = $param->{hash};
    my $name = $hash->{NAME};

    if ( $err eq "" ) {    # kein Fehler aufgetreten
        Log3 $name, 3, "eufySecurity $name (Callback getHubs) - data: $data";

        ### Check if json can be parsed into hash
        eval {
            $json = decode_json( encode_utf8($data) );
            1;
        } or do {
            ### Log Entry for debugging purposes
            Log3 $name, 3, "eufySecurity $name (Callback getHubs) - Error decode json";
            return "eufySecurity $name (Callback getHubs) - Error decode json";
        };

        if ( $json->{code} == 0 ) {
            for ( $i = 0 ; $i < @{ $json->{data} } ; $i++ ) {
                Log3 $name, 3, "eufySecurity $name (Callback getHubs) - [$i] json: " . $json->{data}[$i];

                # Update Daten über (io_)hash an Station übergeben
                $hash->{helper}{UPDATE} = $json->{data}[$i];
                my $found =
                  Dispatch( $hash, $json->{data}[$i]{device_type} . ":" . $json->{data}[$i]{station_sn} . ":UPDATE" );
                Log3 $name, 3, "eufySecurity $name (Callback getHubs) - found: $found";
            }
        }
        else {
            Log3 $name, 3, "eufySecurity $name (Callback getHubs) - eufySecurity Fehler code: " . $json->{code} . " msg: " . $json->{msg};
        }

    }
    else {
        Log3 $name, 3, "eufySecurity $name (Callback getHubs) - HttpUtils error:$err";
    }
}

# ----------------------------------------------------------------------------
# Callback für getHistory
# ----------------------------------------------------------------------------
sub getHistoryCB($$$) {
    my ( $param, $err, $data ) = @_;
    my $json;
    my $hash = $param->{hash};
    my $name = $hash->{NAME};

    if ( $err eq "" ) {    # kein Fehler aufgetreten
        Log3 $name, 3, "eufySecurity (Callback getHistory) - data: $data";

        ### Check if json can be parsed into hash
        eval {
            $json = decode_json( encode_utf8($data) );
            1;
        } or do {
            ### Log Entry for debugging purposes
            Log3 $name, 3, "eufySecurity (Callback getHistory) - Error decode json";
            return "eufySecurity (Callback getHistory) - Error decode json";
        };

        if ( $json->{code} == 0 ) {
            Log3 $name, 3, "eufySecurity (Callback getHistory) - json: " . $json->{data};

        }
        else {
            Log3 $name, 3, "eufySecurity (Callback getHistory) - eufy Security Fehler code: " . $json->{code} . " msg: " . $json->{msg};
        }

    }
    else {
        Log3 $name, 3, "eufySecurity (Callback getHistory) - HttpUtils Fehler error: $err";
    }
}

sub getDskKey($$) {
    my ( $hash, $data ) = @_;
    my $name = $hash->{NAME};
    my $json;

    Log3 $name, 3, "eufySecurity $name (getDskKey) - data: " . $data;

    my $param = {
        url      => $BaseURL . "app/equipment/get_dsk_keys",
        header   => "Content-Type: application/json\r\n" . "x-auth-token: " . $hash->{connection}{auth_token},
        data     => $data,
        method   => "POST",
        hash     => $hash,
        loglevel => 5,
        timeout  => 10
    };
    Log3 $name, 3, "eufySecurity $name (GetDskKey) - url: " . $param->{url};

    my ( $err, $data ) = HttpUtils_BlockingGet($param);

    if ( $err eq "" ) {    # kein Fehler aufgetreten
        Log3 $name, 3, "eufySecurity (getDskKey) - data: $data";

        ### Check if json can be parsed into hash
        eval {
            $json = decode_json( encode_utf8($data) );
            1;
        } or do {
            ### Log Entry for debugging purposes
            Log3 $name, 3, "eufySecurity (getDskKey) - Error decode json";
            return "eufySecurity (getDskKey) - Error decode json";
        };

        if ( $json->{code} == 0 ) {

            #$debug = Dumper($json);
            #Log3 $name, 3, "eufySecurity $name (getDskKey) - debug: $debug";
            readingsBeginUpdate($hash);
            readingsBulkUpdateIfChanged( $hash, 'dsk_key',            $json->{data}{dsk_keys}[0]{dsk_key},                   1 );
            readingsBulkUpdateIfChanged( $hash, 'dsk_key_expiration', FmtDateTime( $json->{data}{dsk_keys}[0]{expiration} ), 1 );
            readingsEndUpdate( $hash, 1 );
        }
    }
}

# ----------------------------------------------------------------------------
# request list of devices
# ----------------------------------------------------------------------------
sub getDevices($$) {
    my ( $hash, $data ) = @_;
    my $name = $hash->{NAME};

    Log3 $name, 3, "eufySecurity $name (getDevices) - data: " . $data;

    my $param = {
        url      => $BaseURL . 'app/get_devs_list',
        header   => "Content-Type: application/json\r\n" . "x-auth-token: " . $hash->{connection}{auth_token},
        data     => $data,
        method   => "POST",
        hash     => $hash,
        loglevel => 5,
        timeout  => 10,
        callback => \&getDevicesCB
    };
    Log3 $name, 3, "eufySecurity $name (GetDevices) - url: " . $param->{url};
    HttpUtils_NonblockingGet($param);
}

# ----------------------------------------------------------------------------
# Callback Fuction for getDevices
# ----------------------------------------------------------------------------
sub getDevicesCB($$$) {
    my ( $param, $err, $data ) = @_;
    my $json;
    my $hash = $param->{hash};
    my $name = $hash->{NAME};

    if ( $err eq "" ) {    # kein Fehler aufgetreten
        Log3 $name, 3, "eufySecurity (Callback getDevices) - data: $data";

        ### Check if json can be parsed into hash
        eval {
            $json = decode_json( encode_utf8($data) );
            1;
        } or do {
            ### Log Entry for debugging purposes
            Log3 $name, 3, "eufySecurity (Callback getDevicess) - Error decode json";
            return "eufySecurity (Callback getDevices) - Error decode json";
        };

        if ( $json->{code} == 0 ) {
            for ( $i = 0 ; $i < @{ $json->{data} } ; $i++ ) {
                Log3 $name, 3, "eufySecurity (Callback getDevices) - camera: " . $json->{data}[$i]{device_sn};

                # Update Daten über (io_)hash an Kamera übergeben
                $hash->{helper}{UPDATE} = $json->{data}[$i];
                my $found =
                  Dispatch( $hash, $json->{data}[$i]{device_type} . ":" . $json->{data}[$i]{device_sn} . ":UPDATE" );
                Log3 $name, 3, "eufySecurity (Callback getDevices) - found: $found";
            }
        }
        else {
            Log3 $name, 3, "eufySecurity (Callback getDevices) - eufy Security Fehler code: " . $json->{code} . " msg: " . $json->{msg};
        }

    }
    else {
        Log3 $name, 3, "eufySecurity (Callback getDevices) - HttpUtils Fehler $err";
    }
}

sub encrypt_Password($$) {
    my ( $password, $key ) = @_;

    return undef unless ( defined($password) );

    if ( eval "use Digest::MD5;1" ) {
        $key = Digest::MD5::md5_hex( unpack "H*", $key );
        $key .= Digest::MD5::md5_hex($key);
    }

    my $enc_pwd = '';

    for my $char ( split //, $password ) {
        my $encode = chop($key);
        $enc_pwd .= sprintf( "%.2x", ord($char) ^ ord($encode) );
        $key = $encode . $key;
    }

    return $enc_pwd;
}

sub decrypt_Password($$) {
    my ( $password, $key ) = @_;

    return undef unless ( defined($password) );

    if ( eval "use Digest::MD5;1" ) {
        $key = Digest::MD5::md5_hex( unpack "H*", $key );
        $key .= Digest::MD5::md5_hex($key);
    }

    my $dec_pwd = '';

    for my $char ( map { pack( 'C', hex($_) ) } ( $password =~ /(..)/g ) ) {
        my $decode = chop($key);
        $dec_pwd .= chr( ord($char) ^ ord($decode) );
        $key = $decode . $key;
    }

    return $dec_pwd;
}

# ----------------------------------------------------------------------------
# Return first two bytes of P2P Message
# ----------------------------------------------------------------------------
sub hasHeader($$) {
    my ( $msg, $type ) = @_;
    return substr( $msg, 0, 2 ) eq $type;
}

# Eval-Rückgabewert für erfolgreiches
# Laden des Moduls

1;

# Beginn der Commandref

=pod
=item [helper|device|command]
=item summary Kurzbeschreibung in Englisch was MYMODULE steuert/unterstützt
=item summary_DE Kurzbeschreibung in Deutsch was MYMODULE steuert/unterstützt

=begin html
 Englische Commandref in HTML
=end html

=begin html_DE
 Deutsche Commandref in HTML
=end html

# Ende der Commandref
=cut
