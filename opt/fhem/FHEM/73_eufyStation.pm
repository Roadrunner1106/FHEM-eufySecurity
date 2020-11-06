#
#  73_eufyStation.pm
#

package main;

# Laden evtl. abhängiger Perl- bzw. FHEM-Hilfsmodule

# Wenn 1 werden alle Attribute und Parameter als Readings im Device dargestellt
my $DEBUG_READINGS = 1;

# eufyStation Modulfunktionen

sub eufyStation_Initialize($) {
    my ($hash) = @_;

    $hash->{DefFn}    = "eufyStation_Define";
    $hash->{UndefFn}  = "eufyStation_Undef";
    $hash->{DeleteFn} = "eufyStation_Delete";
    $hash->{SetFn}    = "eufyStation_Set";
    $hash->{GetFn}    = "eufyStation_Get";

    #$hash->{AttrFn}   = "eufyStation_Attr";

    # Noch nicht implementierte Funktionen auskommentiert
    #$hash->{ReadFn}               = "eufyStation_Read";
    #$hash->{ReadyFn}              = "eufyStation_Ready";
    #$hash->{NotifyFn}             = "eufyStation_Notify";
    #$hash->{RenameFn}             = "eufyStation_Rename";
    #$hash->{ShutdownFn}           = "eufyStation_Shutdown";
    #$hash->{DelayedShutdownFn}    = "eufyStation_ DelayedShutdown";rmat

    # Funktionen für zweistufiges Modulkonzept
    $hash->{ParseFn}       = "eufyStation_Parse";
    $hash->{FingerprintFn} = "eufyStation_Fingerprint";
    $hash->{Match}         = "^0:.*";

    # autocreate Option setzen
    $hash->{noAutocreatedFilelog} = 1;

    $hash->{AttrList} = $readingFnAttributes;
}

# define eunfyStation_T8010P2320270E8D eufyStation 0 T8010P2320270E8D
# define $name $model $device_type $station_sn
sub eufyStation_Define($$) {
    my ( $hash, $def ) = @_;
    my ( $name, $modul, $device_type, $station_sn ) = split( / /, $def );

    # Log3 undef, 3, "eufyStation (DEBUG) - $a ".scalar( @{$a} );
    #return 'too few parameters: define <NAME> eufyStation'
    #  if ( int(@param) < 2 );

    # Adresse rückwärts dem Hash zuordnen (für ParseFn)
    $modules{eufyStation}{defptr}{$station_sn} = $hash;

    # Verbindung für IOWrite() zum physischen Geräte (eufySecurity)
    AssignIoPort($hash);

    # Device ggf. den Raum eufySecurity zuweisen
    CommandAttr( undef, $name . ' room eufySecurity' )
      if ( AttrVal( $name, 'room', 'none' ) eq 'none' );

    # Readings mit Default-Werten vorbesetzen

    Log3 $name, 3, "eufyStation $name (Define) - defined";
    return undef;
}

sub eufyStation_Undef($$) {
    my ( $hash, $name ) = @_;

    # TBD: Hier noch offene Verbindungne schliessen

    Log3 $name, 3, "eufyStation $name (Undef) - undefined";

    return undef;
}

sub eufyStation_Delete ($$) {
    my $hash = shift;
    my $name = shift;
    my ( $device_type, $station_sn ) = $hash->{DEF};

    # Adresse rückwärts dem Hash zuordnen (für ParseFn)
    delete $modules{eufyStation}{defptr}{$station_sn};
    Log3 $name, 3, "eufyStation $name (Delete) - deleted";

    return undef;
}

sub eufyStation_Set($@) {
    my ( $hash, $name, $cmd, @args ) = @_;

    return undef;
}

sub eufyStation_Get($$@) {
    my ( $hash, $name, $opt, @args ) = @_;
    my $ret;
    my $message;
    my ( $device_type, $station_sn ) = split( / /, $hash->{DEF} );

    return "\"get $name\" needs at least one argument" unless ( defined($opt) );
    Log3 $name, 3, "eufyStation $name (Get) - cmd: $opt";

    if ( $opt eq "Update" ) {
        Log3 $name, 3, "eufyStation $name (get) - update station";
        $message = $device_type . ":" . $station_sn . ":UPDATE_HUB";
        Log3 $name, 3, "eufyStation $name (get) - IOWrite message: " . $message;
        $ret = IOWrite( $hash, $message );
        Log3 $name, 3, "eufyStation $name (get) - IOWrite return: $ret";
    }
    elsif ( $opt eq "DskKey" ) {
        Log3 $name, 3, "eufyStation $name (get) -  DskKey";
        $message = $device_type . ":" . $station_sn . ":GET_DSK_KEY";
        Log3 $name, 3, "eufyStation $name (get) - IOWrite message: " . $message;
        $ret = IOWrite( $hash, $message );
        Log3 $name, 3, "eufyStation $name (get) - IOWrite return: $ret";
    }
    else {
        return "Unknown argument $opt, choose one of Update DskKey";
    }

    return undef;
}

sub eufyStation_Parse ($$) {
    my ( $io_hash, $message ) = @_;
    my ( $device_type, $station_sn, $cmd ) = split( /:/, $message );
    my $name = 'eufyStation_' . $station_sn;

    # wenn bereits eine Gerätedefinition existiert (via Definition Pointer aus Define-Funktion)
    if ( my $hash = $modules{eufyStation}{defptr}{$station_sn} ) {

        # Nachricht für $hash verarbeiten
        Log3 $name, 3, "eufyStation $name (Parse) - station_sn:" . $station_sn . " im Hash gefunden, starte UPDATE";

        # Set alias to station_name
        CommandAttr( undef, $name . ' alias ' . $io_hash->{helper}{UPDATE}{station_name} );

        # Nachricht für $hash verarbeiten
        if ($DEBUG_READINGS) {
            Log3 $name, 3, "eufyStation $name (Parse) - Generate all attributes as Reading";
            readingsBeginUpdate($hash);
            while ( ( $key, $val ) = each %{ $io_hash->{helper}{UPDATE} } ) {
                if ( $key eq 'params' ) {

                    # set reading for param array
                    for ( $param = 0 ; $param < @{ $io_hash->{helper}{UPDATE}{params} } ; $param++ ) {
                        readingsBulkUpdateIfChanged(
                            $hash,
                            $io_hash->{helper}{UPDATE}{params}[$param]{param_type},
                            $io_hash->{helper}{UPDATE}{params}[$param]{param_value}, 1
                        );
                    }
                }
                elsif ( $key eq 'member' ) {
                    while ( ( $k, $v ) = each %{ $io_hash->{helper}{UPDATE}{$key} } ) {
                        if ( substr( $k, -5 ) eq '_time' ) {
                            readingsBulkUpdateIfChanged( $hash, $key . "/" . $k, FmtDateTime($v), 1 );
                        }
                        else {
                            readingsBulkUpdateIfChanged( $hash, $key . "/" . $k, $v, 1 );
                        }
                    }
                }
                elsif ( $key eq 'devices' ) {

                    #Log3 $name, 3, "eufyStation $name (Parse) - enter Devices";
                    for ( my $i = 0 ; $i < @{ $io_hash->{helper}{UPDATE}{$key} } ; $i++ ) {
                        my $sn = $io_hash->{helper}{UPDATE}{$key}[$i]{device_sn};

                        #Log3 $name, 3, "eufyStation $name (Parse) - enter Devices sn:$sn";
                        while ( ( $k, $v ) = each %{ $io_hash->{helper}{UPDATE}{$key}[$i] } ) {

                            #Log3 $name, 3, "eufyStation $name (Parse) - enter Devices k:$k v:$v";
                            if ( substr( $k, -5 ) eq '_time' ) {
                                readingsBulkUpdateIfChanged( $hash, $key . "/" . $sn . "/" . $k, FmtDateTime($v), 1 );
                            }
                            else {
                                readingsBulkUpdateIfChanged( $hash, $key . "/" . $sn . "/" . $k, $v, 1 );
                            }
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
            Log3 $name, 3, "eufyStation $name (Parse) - generate only important attributes as Reading";

            # Update der relevanten Readings
            readingsBeginUpdate($hash);
            readingsBulkUpdateIfChanged( $hash, 'station_name',       $io_hash->{helper}{UPDATE}{station_name},                      1 );
            readingsBulkUpdateIfChanged( $hash, 'station_id',         $io_hash->{helper}{UPDATE}{station_id},                        1 );
            readingsBulkUpdateIfChanged( $hash, 'station_sn',         $io_hash->{helper}{UPDATE}{station_sn},                        1 );
            readingsBulkUpdateIfChanged( $hash, 'device_type',        $DeviceType{ $io_hash->{helper}{UPDATE}{device_type} }[1],     1 );
            readingsBulkUpdateIfChanged( $hash, 'station_model',      $io_hash->{helper}{UPDATE}{station_model},                     1 );
            readingsBulkUpdateIfChanged( $hash, 'time_zone',          $io_hash->{helper}{UPDATE}{time_zone},                         1 );
            readingsBulkUpdateIfChanged( $hash, 'station_id',         $io_hash->{helper}{UPDATE}{station_id},                        1 );
            readingsBulkUpdateIfChanged( $hash, 'wifi_ssid',          $io_hash->{helper}{UPDATE}{wifi_ssid},                         1 );
            readingsBulkUpdateIfChanged( $hash, 'ip_addr',            $io_hash->{helper}{UPDATE}{ip_addr},                           1 );
            readingsBulkUpdateIfChanged( $hash, 'wifi_mac',           $io_hash->{helper}{UPDATE}{wifi_mac},                          1 );
            readingsBulkUpdateIfChanged( $hash, 'sub1g_mac',          $io_hash->{helper}{UPDATE}{sub1g_mac},                         1 );
            readingsBulkUpdateIfChanged( $hash, 'main_hw_version',    $io_hash->{helper}{UPDATE}{main_hw_version},                   1 );
            readingsBulkUpdateIfChanged( $hash, 'main_sw_version',    $io_hash->{helper}{UPDATE}{main_sw_version},                   1 );
            readingsBulkUpdateIfChanged( $hash, 'main_sw_time',       FmtDateTime( $io_hash->{helper}{UPDATE}{main_sw_time} ),       1 );
            readingsBulkUpdateIfChanged( $hash, 'sec_sw_version',     $io_hash->{helper}{UPDATE}{sec_sw_version},                    1 );
            readingsBulkUpdateIfChanged( $hash, 'sec_sw_time',        FmtDateTime( $io_hash->{helper}{UPDATE}{sec_sw_time} ),        1 );
            readingsBulkUpdateIfChanged( $hash, 'sec_hw_version',     $io_hash->{helper}{UPDATE}{sec_hw_version},                    1 );
            readingsBulkUpdateIfChanged( $hash, 'volume',             $io_hash->{helper}{UPDATE}{volume},                            1 );
            readingsBulkUpdateIfChanged( $hash, 'setup_code',         $io_hash->{helper}{UPDATE}{setup_code},                        1 );
            readingsBulkUpdateIfChanged( $hash, 'setup_id',           $io_hash->{helper}{UPDATE}{setup_id},                          1 );
            readingsBulkUpdateIfChanged( $hash, 'event_num',          $io_hash->{helper}{UPDATE}{time_zone},                         1 );
            readingsBulkUpdateIfChanged( $hash, 'create_time',        FmtDateTime( $io_hash->{helper}{UPDATE}{create_time} ),        1 );
            readingsBulkUpdateIfChanged( $hash, 'update_time',        FmtDateTime( $io_hash->{helper}{UPDATE}{update_time} ),        1 );
            readingsBulkUpdateIfChanged( $hash, 'state',              $io_hash->{helper}{UPDATE}{status},                            1 );
            readingsBulkUpdateIfChanged( $hash, 'station_status',     $io_hash->{helper}{UPDATE}{station_status},                    1 );
            readingsBulkUpdateIfChanged( $hash, 'status_change_time', FmtDateTime( $io_hash->{helper}{UPDATE}{status_change_time} ), 1 );

            readingsBulkUpdateIfChanged( $hash, 'p2p_did',            $io_hash->{helper}{UPDATE}{p2p_did},            1 );
            readingsBulkUpdateIfChanged( $hash, 'push_did',           $io_hash->{helper}{UPDATE}{push_did},           1 );
            readingsBulkUpdateIfChanged( $hash, 'p2p_license',        $io_hash->{helper}{UPDATE}{p2p_license},        1 );
            readingsBulkUpdateIfChanged( $hash, 'push_license',       $io_hash->{helper}{UPDATE}{push_license},       1 );
            readingsBulkUpdateIfChanged( $hash, 'ndt_did',            $io_hash->{helper}{UPDATE}{ndt_did},            1 );
            readingsBulkUpdateIfChanged( $hash, 'ndt_license',        $io_hash->{helper}{UPDATE}{ndt_license},        1 );
            readingsBulkUpdateIfChanged( $hash, 'wakeup_flag',        $io_hash->{helper}{UPDATE}{wakeup_flag},        1 );
            readingsBulkUpdateIfChanged( $hash, 'p2p_conn',           $io_hash->{helper}{UPDATE}{p2p_conn},           1 );
            readingsBulkUpdateIfChanged( $hash, 'app_conn',           $io_hash->{helper}{UPDATE}{app_conn},           1 );
            readingsBulkUpdateIfChanged( $hash, 'wipn_enc_dec_key',   $io_hash->{helper}{UPDATE}{wipn_enc_dec_key},   1 );
            readingsBulkUpdateIfChanged( $hash, 'wipn_ndt_aes128key', $io_hash->{helper}{UPDATE}{wipn_ndt_aes128key}, 1 );
            readingsBulkUpdateIfChanged( $hash, 'query_server_did',   $io_hash->{helper}{UPDATE}{query_server_did},   1 );
            readingsBulkUpdateIfChanged( $hash, 'prefix',             $io_hash->{helper}{UPDATE}{prefix},             1 );
            readingsBulkUpdateIfChanged( $hash, 'wakeup_key',         $io_hash->{helper}{UPDATE}{wakeup_key},         1 );
            readingsBulkUpdateIfChanged( $hash, 'sensor_info',        $io_hash->{helper}{UPDATE}{sensor_info},        1 );
            readingsBulkUpdateIfChanged( $hash, 'is_init_complete',   $io_hash->{helper}{UPDATE}{is_init_complete},   1 );
            readingsEndUpdate( $hash, 1 );
        }

        # Rückgabe des Gerätenamens, für welches die Nachricht bestimmt ist.
        return $hash->{NAME};
    }
    else {
        # Keine Gerätedefinition verfügbar
        # Daher Vorschlag define-Befehl: <NAME> <MODULNAME> <DEVICE_TYPE> <DEVICE_SN>
        return "UNDEFINED eufyStation_" . $station_sn . " eufyStation $device_type $station_sn";
    }
}

sub eufyStation_Fingerprint($$) {
    my ( $io_name, $msg ) = @_;

    Log3 $name, 3, "eufyStation (Fingerprint) - io_name: $io_name msg: $msg";

    #substr( $msg, 2, 2, "--" ); # entferne Empfangsadresse
    #substr( $msg, 4, 1, "-" );  # entferne Hop-Count

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
