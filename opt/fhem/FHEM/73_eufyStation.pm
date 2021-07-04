#
#  73_eufyStation.pm
#

package main;

# Laden evtl. abhängiger Perl- bzw. FHEM-Hilfsmodule
use Data::Dumper qw(Dumper);

# Wenn 1 werden alle Attribute und Parameter als Readings im Device dargestellt
my $DEBUG_READINGS = 0;

use constant GuardMode_Num2String => {
    0  => "AWAY",
    1  => "HOME",
    2  => "SCHEDULE",
    47 => "GEOFENCING",
    63 => "DISARMED",
};

# eufyStation Modulfunktionen
sub eufyStation_Initialize($) {
    my ($hash) = @_;

    $hash->{DefFn}    = "eufyStation_Define";
    $hash->{UndefFn}  = "eufyStation_Undef";
    $hash->{DeleteFn} = "eufyStation_Delete";
    $hash->{SetFn}    = "eufyStation_Set";
    $hash->{GetFn}    = "eufyStation_Get";
    $hash->{AttrFn}    = "eufyStation_Attr";

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
    $hash->{Match}         = "^S:(0|30|31):.*";

    # autocreate Option setzen
    $hash->{noAutocreatedFilelog} = 1;

    $hash->{AttrList} = "userGuardModes ".$readingFnAttributes;
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

	# Default GuardModes im Hash ablegen
	$hash->{GuardMode} = GuardMode_Num2String;

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
    my ( $hash,        $name )       = @_;
    my ( $device_type, $station_sn ) = $hash->{DEF};

    # TBD: Hier noch offene Verbindungne schliessen

    Log3 $name, 3, "eufyStation $name (Undef) - undefined";
    delete $modules{eufyStation}{defptr}{$station_sn};
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
    my $ret;
    my $message;
    my ( $device_type, $station_sn ) = split( / /, $hash->{DEF} );

    $message = $device_type . ":" . $station_sn;

    if ( $cmd eq 'connect' ) {
        my $station_ip;
        if ( $device_type == 0 ) {
            $station_ip = $hash->{data}{params}{1176}{param_value};
            Log3 $name, 3, "eufyStation $name (set) -  Station device type $device_type";
        }
        elsif ( $device_type == 31 || $device_type == 31) {
            $station_ip = $hash->{data}{ip_addr};
            Log3 $name, 3, "eufyStation $name (set) -  Station device type $device_type";
        }
        else {
            return "Unknown Device Type $device_type.";
        }
        my $p2p_did        = $hash->{data}{p2p_did};
        my $action_user_id = $hash->{data}{member}{action_user_id};
        $message .= ":CONNECT_STATION:$station_ip:$p2p_did:$action_user_id:$device_type";

        if ( $station_ip ne '' and $p2p_did ne '' and $action_user_id ne '' ) {
            Log3 $name, 3, "eufyStation $name (set) -  connet to station ($station_ip)";
            $ret = IOWrite( $hash, $message );
            Log3 $name, 3, "eufyStation $name (set) - IOWrite return: $ret";
        }
        else {
            Log3 $name, 3, "eufyStation $name (set) -  station_ip:$station_ip p2p_did:$p2p_did action_user_id:$action_user_id  device_type:$device_type";
            Log3 $name, 3, "eufyStation $name (set) -  error connect. Some required values not available. Please execute <set stationname update> first.";
            return "Error. See log";
        }
    }
    elsif ( $cmd eq 'disconnect' ) {

        #if ($hash->{P2P}{$station_sn}{state} eq 'connect') {
        $message .= ":DISCONNECT_STATION";
        $ret = IOWrite( $hash, $message );
        Log3 $name, 3, "eufyStation $name (set) - IOWrite return: $ret";

        #}
    }
    elsif ( $cmd eq 'GuardMode' ) {
        Log3 $name, 3, "eufyStation $name (set) -  set station to GuardMode " . $args[0];
		
		# get GuardMode-Key from GuardMode-String
		my ($key) = grep{ $hash->{GuardMode}{$_} eq $args[0] } keys %{$hash->{GuardMode}};
        $message .= ":GUARD_MODE:" . $key;

        $ret = IOWrite( $hash, $message );
        Log3 $name, 3, "eufyStation $name (set) - IOWrite return: $ret";
    }
    else {
        return "Unknown argument $cmd, choose one of connect:noArg disconnect:noArg GuardMode:".getGuardModes($hash);
    }
}

sub eufyStation_Get($$@) {
    my ( $hash, $name, $opt, @args ) = @_;
    my $ret;
    my $message;
    my ( $device_type, $station_sn ) = split( / /, $hash->{DEF} );

    return "\"get $name\" needs at least one argument" unless ( defined($opt) );
    Log3 $name, 3, "eufyStation $name (Get) - cmd: $opt";

    if ( $opt eq "update" ) {
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
        return "Unknown argument $opt, choose one of update:noArg DskKey:noArg";
    }

    return undef;
}

sub eufyStation_Attr($$$$) {
	my ( $cmd, $name, $attrName, $attrValue ) = @_;
    my $hash   = $defs{$name};
	
  	# $cmd  - Vorgangsart - kann die Werte "del" (löschen) oder "set" (setzen) annehmen
	# $name - Gerätename
	# $attrName/$attrValue sind Attribut-Name und Attribut-Wert
    
	if ($cmd eq "set") {
		if ($attrName eq "userGuardModes") {
			# attrVal = "mode_num:mode_string;mode_num:mode_string;..."
			my @userModes = split(/;/,$attrValue);

			for (my $i=0; $i<@userModes; $i++) {
			    my ($n,$s)=split(/:/,$userModes[$i]);
			    $hash->{GuardMode}{$n}=$s;
			}
		}
	} elsif ($cmd eq "del") {
		if ($attrName eq "userGuardModes") {
			my @userModes = split(/;/,$attrValue);

			for (my $i=0; $i<@userModes; $i++) {
			    my ($n,$s)=split(/:/,$userModes[$i]);
			    delete $hash->{GuardMode}{$n};
			}			
		}
	}
	return undef;
}

sub eufyStation_Parse ($$) {
    my ( $io_hash, $message ) = @_;
    my ( undef, $device_type, $station_sn, $cmd, @args ) = split( /:/, $message );
    my $name = 'eufyStation_' . $station_sn;

    #my $hash   = $defs{$name};
	
    # wenn bereits eine Gerätedefinition existiert (via Definition Pointer aus Define-Funktion)
    if ( my $hash = $modules{eufyStation}{defptr}{$station_sn} ) {

        # Nachricht für $hash verarbeiten
        Log3 $name, 3, "eufyStation $name (Parse) - station_sn:" . $station_sn . " im Hash gefunden, führe cmd $cmd aus";

        if ( $cmd eq 'UPDATE' ) {

            # delete old data information
            delete $hash->{data};

            # copy data of io_hash tp device hash
            $hash->{data} = $io_hash->{helper}{UPDATE};

            # rename key params to params_old and convert array to hash
            $hash->{data}{params_old} = delete $hash->{data}{params};
            for ( $i = 0 ; $i < @{ $hash->{data}{params_old} } ; $i++ ) {
                my $param_type = $hash->{data}{params_old}[$i]{param_type};
                delete $hash->{data}{params_old}[$i]{param_type};
                delete $hash->{data}{params_old}[$i]{station_sn};
                $hash->{data}{params}{$param_type} = $hash->{data}{params_old}[$i];
            }
            delete $hash->{data}{params_old};

            # rename key devices tp devices_old and convert array to hash
            $hash->{data}{devices_old} = delete $hash->{data}{devices};
            for ( $i = 0 ; $i < @{ $hash->{data}{devices_old} } ; $i++ ) {
                my $device_sn = $hash->{data}{devices_old}[$i]{device_sn};
                delete $hash->{data}{devices_old}[$i]{device_sn};
                $hash->{data}{devices}{$device_sn} = $hash->{data}{devices_old}[$i];
            }
            delete $hash->{data}{devices_old};

            # Log3 $name, 3, "eufyStation $name (Parse) - Dumper " . Dumper( $hash->{data} );

            # Set alias to station_name
            CommandAttr( undef, $name . ' alias ' . $hash->{data}{station_name} );

            # Nachricht für $hash verarbeiten
            if ($DEBUG_READINGS) {
                Log3 $name, 3, "eufyStation $name (Parse) - Generate all attributes as Reading";
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
                    elsif ( $key eq 'member' ) {
                        while ( ( $k, $v ) = each %{ $io_hash->{data}{$key} } ) {
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
                        for ( my $i = 0 ; $i < @{ $io_hash->{data}{$key} } ; $i++ ) {
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
                readingsBulkUpdateIfChanged( $hash, 'station_id',    $hash->{data}{station_id},                    1 ) if defined $hash->{data}{station_id};
                readingsBulkUpdateIfChanged( $hash, 'device_type',   $DeviceType{ $hash->{data}{device_type} }[1], 1 ) if defined $hash->{data}{device_type};
                readingsBulkUpdateIfChanged( $hash, 'station_model', $hash->{data}{station_model},                 1 ) if defined $hash->{data}{station_model};
                readingsBulkUpdateIfChanged( $hash, 'time_zone',     $hash->{data}{time_zone},                     1 ) if defined $hash->{data}{time_zone};
                readingsBulkUpdateIfChanged( $hash, 'wifi_ssid',     $hash->{data}{wifi_ssid},                     1 ) if defined $hash->{data}{wifi_ssid};
                readingsBulkUpdateIfChanged( $hash, 'ip_addr',       $hash->{data}{ip_addr},                       1 ) if defined $hash->{data}{ip_addr};
                readingsBulkUpdateIfChanged( $hash, 'wifi_mac',      $hash->{data}{wifi_mac},                      1 ) if defined $hash->{data}{wifi_mac};
                readingsBulkUpdateIfChanged( $hash, 'main_hw_version', $hash->{data}{main_hw_version}, 1 ) if defined $hash->{data}{main_hw_version};
                readingsBulkUpdateIfChanged( $hash, 'main_sw_version', $hash->{data}{main_sw_version}, 1 ) if defined $hash->{data}{main_sw_version};
                readingsBulkUpdateIfChanged( $hash, 'main_sw_time',    FmtDateTime( $hash->{data}{main_sw_time} ), 1 ) if defined $hash->{data}{main_sw_time};
                readingsBulkUpdateIfChanged( $hash, 'sec_sw_version',  $hash->{data}{sec_sw_version},              1 ) if defined $hash->{data}{sec_sw_version};
                readingsBulkUpdateIfChanged( $hash, 'sec_sw_time',     FmtDateTime( $hash->{data}{sec_sw_time} ),  1 ) if defined $hash->{data}{sec_sw_time};
                readingsBulkUpdateIfChanged( $hash, 'sec_hw_version',  $hash->{data}{sec_hw_version},              1 ) if defined $hash->{data}{sec_hw_version};
                readingsBulkUpdateIfChanged( $hash, 'event_num',       $hash->{data}{event_num},                   1 ) if defined $hash->{data}{event_num};
                readingsBulkUpdateIfChanged( $hash, 'create_time',     FmtDateTime( $hash->{data}{create_time} ),  1 ) if defined $hash->{data}{create_time};
                readingsBulkUpdateIfChanged( $hash, 'update_time',     FmtDateTime( $hash->{data}{update_time} ),  1 ) if defined $hash->{data}{update_time};
                readingsBulkUpdateIfChanged( $hash, 'state',           $hash->{data}{status},                      1 ) if defined $hash->{data}{status};
                readingsBulkUpdateIfChanged( $hash, 'p2p_did',         $hash->{data}{p2p_did},                     1 ) if defined $hash->{data}{p2p_did};
                readingsBulkUpdateIfChanged( $hash, 'ip_addr',         $hash->{data}{ip_addr},                     1 ) if defined $hash->{data}{ip_addr};
                readingsBulkUpdateIfChanged( $hash, 'ip_addr_local',   $hash->{data}{params}{1176}{param_value},   1 )
                  if defined $hash->{data}{params}{1176}{param_value};

	  			my $GuardModeName = $hash->{GuardMode}{$hash->{data}{params}{1224}{param_value}};
	  			$GuardModeName = $hash->{data}{params}{1224}{param_value} if (undef($GuardModeName));
				Log3 $name, 3, "eufyStation $name (Parse) - guardmodename: $GuardModeName";
                readingsBulkUpdateIfChanged( $hash, 'guard_mode', $GuardModeName, 1 )
                  if defined $hash->{data}{params}{1224}{param_value};
                readingsEndUpdate( $hash, 1 );
            }

            # Rückgabe des Gerätenamens, für welches die Nachricht bestimmt ist.
            return $hash->{NAME};
        }
        elsif ( $cmd eq 'SET_P2P_STATE' ) {
			Log3 $name, 3, "eufyStation $name (Parse) - P2P-State is set to ".$args[0];
            readingsBeginUpdate($hash);
            readingsBulkUpdateIfChanged( $hash, 'p2p_state', $args[0], 1 );
            readingsEndUpdate( $hash, 1 );
            return $hash->{NAME};
        }
        elsif ( $cmd eq 'SET_GUARDMODE' ) {
            $hash->{data}{params}{1224}{param_value} = $args[0];
			my $GuardModeName = $hash->{GuardMode}{$args[0]};
			$GuardModeName = $args[0] if ($GuardModeName eq "");
			Log3 $name, 3, "eufyStation $name (Parse) - GuardMode is set to ".$GuardModeName;
            readingsBeginUpdate($hash);
            readingsBulkUpdate( $hash, 'guard_mode', $GuardModeName, 1 );
            readingsEndUpdate( $hash, 1 );
			return $hash->{NAME};
        }
        else {
            Log3 $name, 3, "eufyStation $name (Parse) - Unknown cmd $cmd";
        }
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

# Returns a comma-separated list of all GuardModes
sub getGuardModes($) {
    my $hash = shift;
    my $gm;
    
    foreach $v (values %{$hash->{GuardMode}}) {
        $gm .= "," if $gm ne '';
        $gm .= $v;
    }
    
    return $gm;
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
<a name="eufyStation"></a>
<h3>eufyStation</h3>

 Englische Commandref in HTML
=end html

=begin html_DE
<a name="eufyStation"></a>
<h3>eufyStation</h3>

 Deutsche Commandref in HTML
=end html_DE

# Ende der Commandref
=cut
