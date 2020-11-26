#
#  73_eufyCamera.pm
#

package main;

# Laden evtl. abhängiger Perl- bzw. FHEM-Hilfsmodule
use Data::Dumper qw(Dumper);

# Wenn 1 werden alle Attribute und Parameter als Readings im Device dargestellt
my $DEBUG_READINGS = 0;

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
    30 => [ 'INDOOR_CAMERA',    'Indoor Camera 2k' ],    # Cam & Station in one device
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
    CommandAttr( undef, $name . ' userReadings battery { ReadingsVal($NAME,"battery_level",0) > 10 ? "ok" : "low"}' )
      if ( AttrVal( $name, 'userReadings', 'none' ) eq 'none' );

    # Default-Werte für schnellen API-Zugriff im $hash ablegen

    # Readings mit Default-Werten vorbesetzen

    Log3 $name, 3, "eufyCamera (Define) - defined $name";
    return undef;
}

sub eufyCamera_Undef($$) {
    my ( $hash,        $name )      = @_;
    my ( $device_type, $device_sn ) = $hash->{DEF};

    # TBD: Hier noch offene Verbindungne schliessen

    # Readings auf Default-Werte setzen

    Log3 $name, 3, "eufyCamera (Undef) - undefined $name";
    delete $modules{eufyCamera}{defptr}{$device_sn};
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
        return "Unknown argument $opt, choose one of update:noArg";
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
        Log3 $name, 3, "eufyCamera (Parse) - device_sn" . $device_sn . " found in the hash";

        if ( $cmd eq 'UPDATE' ) {
            Log3 $name, 3, "eufyCamera (Parse) - device_sn" . $device_sn . " start UPDATE";

            # copy data of io_hash to device hash
            $hash->{data} = $io_hash->{helper}{UPDATE};

            # rename key params tp params_old and convert array to hash
            $hash->{data}{params_old} = delete $hash->{data}{params};
            for ( $i = 0 ; $i < @{ $hash->{data}{params_old} } ; $i++ ) {
                my $param_type = $hash->{data}{params_old}[$i]{param_type};
                delete $hash->{data}{params_old}[$i]{param_type};
                delete $hash->{data}{params_old}[$i]{device_sn};
                $hash->{data}{params}{$param_type} = $hash->{data}{params_old}[$i];
            }
            delete $hash->{data}{params_old};

            #Log3 $name, 3, "eufyStation $name (Parse) - Dumper " . Dumper( $hash->{data} );

            # Set alias to device_name
            CommandAttr( undef, $name . ' alias ' . $hash->{data}{device_name} );

            if ($DEBUG_READINGS) {
                Log3 $name, 3, "eufyCamera $name (Parse) - Generate all attributes as Reading";
                readingsBeginUpdate($hash);
                while ( ( $key, $val ) = each %{ $io_hash->{data} } ) {
                    if ( $key eq 'params' ) {

                        # set reading for params
                        while ( ( $p, $h ) = each %{ $hash->{data}{params} } ) {
                            my $param_type = $p;
                            while ( ( $k, $v ) = each %{$h} ) {
                                readingsBulkUpdateIfChanged( $hash, "params/$param_type/$k", $hash->{data}{params}{$k}{param_value}, 1 );
                            }
                        }
                    }
                    elsif ( $key eq 'station_conn' or $key eq 'member' ) {
                        while ( ( $k, $v ) = each %{ $io_hash->{data}{$key} } ) {
                            if ( substr( $k, -5 ) eq '_time' ) {
                                readingsBulkUpdateIfChanged( $hash, $key . "/" . $k, FmtDateTime($v), 1 );
                            }
                            else {
                                readingsBulkUpdateIfChanged( $hash, $key . "/" . $k, $v, 1 );
                            }
                        }
                    }
                    else {
                        if ( substr( $key, -5 ) eq '_time' ) {
                            readingsBulkUpdateIfChanged( $hash, $key, FmtDateTime($val), 1 );
                        }
                        else {
                            readingsBulkUpdateIfChanged( $hash, $key, $val, 1 );
                        }
                    }
                }
                readingsEndUpdate( $hash, 1 );
            }
            else {
                # Log3 $name, 3, "eufyCamera (Parse) - Dumper UPDATE-Hash\n".Dumper($io_hash->{helper}{UPDATE})."\n";

                # Update der relevanten Readings
                readingsBeginUpdate($hash);

                #readingsBulkUpdateIfChanged( $hash, 'bind_time',        FmtDateTime( $hash->{data}{bind_time} ),1 );
                #readingsBulkUpdateIfChanged( $hash, 'charging_days',    $hash->{data}{charging_days},1 );
                #readingsBulkUpdateIfChanged( $hash, 'charging_missing', $hash->{data}{charging_missing},1 );
                #readingsBulkUpdateIfChanged( $hash, 'charging_reserve', $hash->{data}{charging_reserve},1 );
                #readingsBulkUpdateIfChanged( $hash, 'charing_total',    $hash->{data}{charing_total},1 );
                #readingsBulkUpdateIfChanged( $hash, 'cover_path',       $hash->{data}{cover_path} );
                #readingsBulkUpdateIfChanged( $hash, 'cover_time',       FmtDateTime( $hash->{data}{cover_time} ),1 );
                #readingsBulkUpdateIfChanged( $hash, 'device_id',        $hash->{data}{device_id},1 );
                readingsBulkUpdateIfChanged( $hash, 'create_time',     FmtDateTime( $hash->{data}{create_time} ),          1 );
                readingsBulkUpdateIfChanged( $hash, 'device_channel',  $hash->{data}{device_channel},                      1 );
                readingsBulkUpdateIfChanged( $hash, 'device_model',    $hash->{data}{device_model},                        1 );
                readingsBulkUpdateIfChanged( $hash, 'device_type',     $DeviceType{ $hash->{data}{device_type} }[1],       1 );
                readingsBulkUpdateIfChanged( $hash, 'event_num',       $hash->{data}{event_num},                           1 );
                readingsBulkUpdateIfChanged( $hash, 'main_hw_version', $hash->{data}{main_hw_version},                     1 );
                readingsBulkUpdateIfChanged( $hash, 'main_sw_version', $hash->{data}{UPDATE}{main_sw_version},             1 );
                readingsBulkUpdateIfChanged( $hash, 'main_sw_time',    FmtDateTime( $hash->{data}{UPDATE}{main_sw_time} ), 1 );
                readingsBulkUpdateIfChanged( $hash, 'sec_sw_version',  $hash->{data}{sec_sw_version},                      1 );
                readingsBulkUpdateIfChanged( $hash, 'sec_sw_time',     FmtDateTime( $hash->{data}{sec_sw_time} ),          1 );
                readingsBulkUpdateIfChanged( $hash, 'update_time',     FmtDateTime( $hash->{data}{update_time} ),          1 );
                readingsBulkUpdateIfChanged( $hash, 'state',           $hash->{data}{status},                              1 );
                readingsBulkUpdateIfChanged( $hash, 'battery_level',   $hash->{data}{params}{1101}{param_value},           1 );
                readingsBulkUpdateIfChanged( $hash, 'wifiRSSI',        $hash->{data}{params}{1142}{param_value},           1 );
                readingsEndUpdate( $hash, 1 );
            }

            # Rückgabe des Gerätenamens, für welches die Nachricht bestimmt ist.
            return $hash->{NAME};
        }
        else {
            Log3 $name, 3, "eufyCamera $name (Parse) - Unknown cmd $cmd";
        }
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
