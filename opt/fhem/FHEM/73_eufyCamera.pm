#
#  73_eufyCamera.pm
#

package main;

# Laden evtl. abhängiger Perl- bzw. FHEM-Hilfsmodule

# Wenn 1 werden alle Attribute und Parameter als Readings im Device dargestellt
my $DEBUG_READINGS = 1;

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
    30 => [ 'INDOOR_CAMERA',    'Indoor Camera 2k' ],
    31 => [ 'INDOOR_PT_CAMERA', 'Indoor PR Camera' ],
    50 => [ 'LOCK_BASIC',       'Lock Basic' ],
    51 => [ 'LOCK_ADVANCED',    'Lock Advanced' ],
    52 => [ 'LOCK_SIMPLE',      'Lock Simple' ]
);

# eufyCamera Modulfunktionen

sub eufyCamera_Initialize($) {
    my ($hash) = @_;

    $hash->{DefFn}    = "eufyCamera_Define";
    $hash->{UndefFn}  = "eufyCamera_Undef";
    $hash->{DeleteFn} = "eufyCamera_Delete";
    $hash->{SetFn}    = "eufyCamera_Set";
    $hash->{GetFn}    = "eufyCamera_Get";

    #$hash->{AttrFn}   = "eufyCamera_Attr";

    # Noch nicht implementierte Funktionen auskommentiert
    #$hash->{ReadFn}               = "eufyCamera_Read";
    #$hash->{ReadyFn}              = "eufyCamera_Ready";
    #$hash->{NotifyFn}             = "eufyCamera_Notify";
    #$hash->{RenameFn}             = "eufyCamera_Rename";
    #$hash->{ShutdownFn}           = "eufyCamera_Shutdown";
    #$hash->{DelayedShutdownFn}    = "eufyCamera_ DelayedShutdown";

    # Funktionen für zweistufiges Modulkonzept
    $hash->{ParseFn}       = "eufyCamera_Parse";
    $hash->{FingerprintFn} = "eufyCamera_Fingerprint";
    $hash->{Match}         = "^(1|7|8|9|30):.*";

    # autocreate Option setzen
    $hash->{noAutocreatedFilelog} = 1;

    $hash->{AttrList} = $readingFnAttributes;
}

sub eufyCamera_Define($$) {
    my ( $hash, $def ) = @_;
    my @param = split( / /, $def );

    # Log3 undef, 3, "eufyCamera (DEBUG) - $a ".scalar( @{$a} );
    #return 'too few parameters: define <NAME> eufyCamera'
    #  if ( int(@param) < 2 );

    my $name        = $param[0];
    my $device_type = $param[2];
    my $device_sn   = $param[3];

    Log3 $name, 3, "eufyCamera (Define) - def:$def";
    Log3 $name, 3, "eufyCamera (Define) - name:$name  device_type:$device_type device_sn:$device_sn";

    # Adresse rückwärts dem Hash zuordnen (für ParseFn)
    $modules{eufyCamera}{defptr}{$device_sn} = $hash;

    # Verbindung für IOWrite() zum physischen Geräte (eufySecurity)
    AssignIoPort($hash);

    # Device ggf. den Raum eufySecurity zuweisen
    CommandAttr( undef, $name . ' room eufySecurity' ) if ( AttrVal( $name, 'room', 'none' ) eq 'none' );
    CommandAttr( undef, $name . ' icon it_camera' )    if ( AttrVal( $name, 'icon', 'none' ) eq 'none' );

    # Default-Werte für schnellen API-Zugriff im $hash ablegen

    # Readings mit Default-Werten vorbesetzen

    Log3 $name, 3, "eufyCamera (Define) - defined $name";
    return undef;
}

sub eufyCamera_Undef($$) {
    my ( $hash, $name ) = @_;

    # TBD: Hier noch offene Verbindungne schliessen

    # Readings auf Default-Werte setzen

    Log3 $name, 3, "eufyCamera (Undef) - undefined $name";

    return undef;
}

sub eufyCamera_Delete ($$) {
    my $hash = shift;
    my $name = shift;
    my ( $device_type, $device_sn ) = $hash->{DEF};

    # Adresse rückwärts dem Hash zuordnen (für ParseFn)
    delete $modules{eufyCamera}{defptr}{$device_sn};

    Log3 $name, 3, "eufyCamera $name (Delete) - deleted $name";

    return undef;
}

sub eufyCamera_Set($@) {
    my ( $hash, $name, $cmd, @args ) = @_;

    return undef;
}

sub eufyCamera_Get($$@) {
    my ( $hash, $name, $opt, @args ) = @_;
    my $ret;
    my $message;
    my ( $device_type, $device_sn ) = split( / /, $hash->{DEF} );

    return "\"get $name\" needs at least one argument" unless ( defined($opt) );

    if ( $opt eq "update" ) {
        Log3 $name, 3, "eufyCamera $name (get) - update camera";
        $message = $device_type . ":" . $device_sn . ":UPDATE_DEVICE";
        Log3 $name, 3, "eufyCamera $name (get) - IOWrite message: " . $message;
        $ret = IOWrite( $hash, $message );
        Log3 $name, 3, "eufyCamera $name (get) - IOWrite return: $ret";
    }
    else {
        return "Unknown argument $opt, choose one of update";
    }

    return undef;
}

sub eufyCamera_Parse ($$) {

    # $io_hash ist der hash vom eufySecurity Device
    my ( $io_hash, $message ) = @_;
    my @msg         = split( /:/, $message );
    my $device_type = $msg[0];
    my $device_sn   = $msg[1];
    my $cmd         = $msg[2];
    my $name        = 'eufyCamera_' . $device_sn;

    Log3 $name, 3, "eufyCamera (Parse) - eufy_device_type:" . $device_type . " device_sn:" . $device_sn . " cmd:" . $cmd;

    # wenn bereits eine Gerätedefinition existiert (via Definition Pointer aus Define-Funktion)
    if ( my $hash = $modules{eufyCamera}{defptr}{$device_sn} ) {

        # Nachricht für $hash verarbeiten
        Log3 $name, 3, "eufyCamera (Parse) - device_sn" . $device_sn . " im Hash gefunden, starte UPDATE";

        # Set alias ti device_name
        CommandAttr( undef, $name . ' alias ' . $io_hash->{helper}{UPDATE}{device_name} );

        if ($DEBUG_READINGS) {
            readingsBeginUpdate($hash);
            while ( ( $key, $val ) = each %{ $io_hash->{helper}{UPDATE} } ) {
                if ( $key ne 'params' ) {
                    if ( substr( $key, -5 ) eq '_time' ) {
                        readingsBulkUpdateIfChanged( $hash, $key, FmtDateTime($val), 1 );
                    }
                    else {
                        if ( $key eq 'station_conn' or $key eq 'member' ) {
                            while ( ( $k, $v ) = each %{ $io_hash->{helper}{UPDATE}{$key} } ) {
                                if ( substr( $k, -5 ) eq '_time' ) {
                                    readingsBulkUpdateIfChanged( $hash, $key . "/" . $k, FmtDateTime($v), 1 );
                                }
                                else {
                                    readingsBulkUpdateIfChanged( $hash, $key . "/" . $k, $v, 1 );
                                }
                            }
                        }
                        else {
                            readingsBulkUpdateIfChanged( $hash, $key, $val, 1 );
                        }
                    }

                }
                else {
                    # set reading for param array
                    for ( $param = 0 ; $param < @{ $io_hash->{helper}{UPDATE}{params} } ; $param++ ) {
                        readingsBulkUpdateIfChanged(
                            $hash,
                            $io_hash->{helper}{UPDATE}{params}[$param]{param_type},
                            $io_hash->{helper}{UPDATE}{params}[$param]{param_value}, 1
                        );
                    }
                }

            }
            readingsEndUpdate( $hash, 1 );
        }
        else {

            # Update der relevanten Readings
            readingsBeginUpdate($hash);
            readingsBulkUpdate( $hash, 'bind_time',        FmtDateTime( $io_hash->{helper}{UPDATE}{bind_time} ) );
            readingsBulkUpdate( $hash, 'charging_days',    $io_hash->{helper}{UPDATE}{charging_days} );
            readingsBulkUpdate( $hash, 'charging_missing', $io_hash->{helper}{UPDATE}{charging_missing} );
            readingsBulkUpdate( $hash, 'charging_reserve', $io_hash->{helper}{UPDATE}{charging_reserve} );
            readingsBulkUpdate( $hash, 'charing_total',    $io_hash->{helper}{UPDATE}{charing_total} );
            readingsBulkUpdate( $hash, 'cover_path',       $io_hash->{helper}{UPDATE}{cover_path} );
            readingsBulkUpdate( $hash, 'cover_time',       FmtDateTime( $io_hash->{helper}{UPDATE}{cover_time} ) );
            readingsBulkUpdate( $hash, 'create_time',      FmtDateTime( $io_hash->{helper}{UPDATE}{create_time} ) );
            readingsBulkUpdate( $hash, 'device_channel',   $io_hash->{helper}{UPDATE}{device_channel} );
            readingsBulkUpdate( $hash, 'device_id',        $io_hash->{helper}{UPDATE}{device_id} );
            readingsBulkUpdate( $hash, 'device_model',     $io_hash->{helper}{UPDATE}{device_model} );
            readingsBulkUpdate( $hash, 'device_sn',        $io_hash->{helper}{UPDATE}{device_sn} );
            readingsBulkUpdate( $hash, 'device_type',      $DeviceType{ $io_hash->{helper}{UPDATE}{device_type} }[1] );
            readingsBulkUpdate( $hash, 'event_num',        $io_hash->{helper}{UPDATE}{event_num} );
            readingsBulkUpdate( $hash, 'main_hw_version',  $io_hash->{helper}{UPDATE}{main_hw_version} );
            readingsBulkUpdate( $hash, 'main_sw_version',  $io_hash->{helper}{UPDATE}{main_sw_version} );
            readingsBulkUpdate( $hash, 'main_sw_time',     FmtDateTime( $io_hash->{helper}{UPDATE}{main_sw_time} ) );
            readingsBulkUpdate( $hash, 'sec_sw_version',   $io_hash->{helper}{UPDATE}{sec_sw_version} );
            readingsBulkUpdate( $hash, 'sec_sw_time',      FmtDateTime( $io_hash->{helper}{UPDATE}{sec_sw_time} ) );
            readingsBulkUpdate( $hash, 'station_sn',       $io_hash->{helper}{UPDATE}{station_sn} );
            readingsBulkUpdate( $hash, 'update_time',      FmtDateTime( $io_hash->{helper}{UPDATE}{update_time} ) );
            readingsBulkUpdate( $hash, 'state',            $io_hash->{helper}{UPDATE}{status} );
            readingsEndUpdate( $hash, 1 );
        }

        # Rückgabe des Gerätenamens, für welches die Nachricht bestimmt ist.
        return $hash->{NAME};
    }
    else {
        # Keine Gerätedefinition verfügbar
        # Daher Vorschlag define-Befehl: <NAME> <MODULNAME> <ADDRESSE>
        Log3 $name, 3, "eufyCamera $name (Parse) - device_sn:" . $device_sn . " nicht im Hash gefunden. Return undefined";
        return 'UNDEFINED ' . 'eufyCamera_' . $device_sn . " eufyCamera " . $device_type . " " . $device_sn;
    }
}

sub eufyCamera_Fingerprint($$) {
    my ( $io_name, $msg ) = @_;

    Log3 $name, 3, "eufyCamera (Fingerprint) - io_name: $io_name msg: $msg";

    #substr( $msg, 2, 2, "--" );    # entferne Empfangsadresse
    #substr( $msg, 4, 1, "-" );     # entferne Hop-Count

    return ( $io_name, $msg );
}

##############################################################################
# Interne Hilfs-Funktionen
##############################################################################

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
