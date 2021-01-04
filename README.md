# FHEM-eufySecurity
FHEM Moduls for eufySecurity devices

## Installation

  Für die Installation einfach die drei Module 73_eufySecurity.pm, 73_eufyStation.pm und 73_eufyCamera.pm und das FHEM-Verzeichnis (/opt/fhem/FHEM) kopieren.

Falls die Module spätere nicht erkannt werden, dann noch einen Restart von FHEM durchführen.

## Kurzanleitung

### eufySecurity Gerät anlegen

Zuerst muss ein eufySecurity-Gerät angelegt werden.

```
define myEufy eufySecurity
```

Dem Gerät wird dann automatisch dem Raum eufySecurity zugewiesen. Das kann aber nachträglich wieder geändert werden.

Danach müssen noch die E-Mail und das Passwort für für den [eufy Security](https://mysecurity.eufylife.com/#/login) Account hinterlegt werden.

```
attr myEufy mail irgendenwas@domain.tld
set myEufy password geheim
```

**Hinweis:** Ich hatte irgendwo gelesen, dass es sinnvoll ist, für den Zugriff über die API einen eigenen Account anzulegen, da sich sonst Zugriffe über die API und die APP gegenseitig blockieren. 

Nachdem alle alle Vorbereitungen abgeschlossen sind, kann mit dem nachfolgenden Kommando eine Verbindung über die Web-API aufgebaut werden.

```
set myEufy connect
```

Wurde die Verbindung erfolgreich aufgebaut, dann sollte STATE auf connect wechseln, ansonsten in das Logfile für einen Fehler schauen.

Nun können mit den nachfolgenden Kommandos die bekannten Geräte ermittelt und angelegt werden.

### Station(s) anlegen

Mit dem Kommado `get myEufy Hubs` wird die Liste der bekannten Stations über die Web-API abgefragt und die bekannten Geräte sollten dann automatisch angelegt werden.

Beim ersten Aufruf wird aktuell nur das Gerät ohne weitere Informationen angelegt. Wird das Kommando erneut aufgerufen, werden auch die Readings mit den Werten zu dem Gerät angelegt.

Wird eine Station nicht automatisch angelegt, kann das auch manuell erfolgen. Siehe Modul eufyStation DEFINE.

### Kamera(s) anlegen

Mit dem Kommado `get myEufy Devices` wird die Liste der bekannten Kameras über die Web-API abgefragt und die bekannten Geräte sollten dann automatisch angelegt werden.

Beim ersten Aufruf wird aktuell nur das Gerät ohne weitere Informationen angelegt. Wird das Kommando erneut aufgerufen, werden auch die Readings mit den Werten zu dem Gerät angelegt.

Wird eine Kamera nicht automatisch angelegt, kann das auch manuell erfolgen. Siehe Modul eufyCamera DEFINE.

### P2P-Verbindung und GuardMode setzen

Damit der GuardMode für eine Station gesetzt werden kann, müssen ein paar Vorbedingungen erfüllt sein.

- Für das eufySecurity Gerät muss eine Verbindung hergestellt sein, damit die erforderlichen Daten der entsprechenden Station abgerufen werden können.
- Für die Station muss mindestens einmal ein Update durchgeführt werden, damit alle erforderlichen Parameter (lokale IP, P2P_DID-String, Action_user_id) verfügbar sind.

Sind die Vorbedingungen erfüllt, kann über das Station-Gerät eine P2P-Verbindung mit `set station_name connect` aufgebaut werden. War das erfolgreich wechselt das Reading _p2p_state_ auf _connect_.

Jetzt kann der GuardMode für die Station mit `set station_name GuardMode mode_name` gesetzt werden.

## Module

### eufySecurity

Das ist das zentrale Modul. Es baut eine Verbindung über die Web-API zum eufy Security Server auf, um dort Daten zu den bekannten Geräten abzufragen.

Außerdem stellt das Modul eine P2P-Verbindung zu jeder bekannte Station her.

#### DEFINE

```
define <name> eufySecurity
```

#### SET

- connect
  Baut eine Verbindung über die Web-API auf.
- password
  Damit kann das Passwort gesetzt werden, was für die Anmeldung über die Web-API benötigt wird.
  Das Passwort wird in FHEM dauerhaft und verschlüsselt gespeichert.
- del_password
  Aktuell nur zum debugging implementiert. Sollte nicht genutzt werden! Entfällt in der finalen Version des Moduls.
- GuardMode
  Setzt den GuardMode für alle bekannten Stations. Aktuell noch ohne Funktion!

#### GET

- Hubs
  Ruft über die Web-API die Liste der Hubs (Stations) ab und reicht die Information an die Station-Geräte weiter. Existiert die Station noch nicht, wird diese per Auto-Create von FHEM angelegt. Die Daten der Station werden dann aber ersten beim nächsten Aufruf am Gerät hinterlegt!
- Devices
  Ruft über die Web-API die Liste der Devices (Kameras) ab und reicht die Information an die Kamera-Geräte weiter. Existiert die Kamera noch nicht, wird diese per Auto-Create von FHEM angelegt. Die Daten der Kamera werden dann aber ersten beim nächsten Aufruf am Gerät hinterlegt!
- History
  Ruft die Historie über die Web-API ab. Aktuell noch ohne Funktion! Es wird nur der zurückgelieferte JSON-String im Logfile protokolliert.
- DEBUG_DskKey
  Aktuell nur zum debugging implementiert. Sollte nicht genutzt werden! Entfällt in der finalen Version des Moduls.

#### ATTRIBUTES

- mail
  Enthält die E-Mail, die für die Anmeldung über die Web-API genutzt wird.

#### READINGS

- devices
  Anzahl der bekannten/definierten Devices. Z.Z. noch keine Funktion und immer 0.
- eufySecurity-API-URL
  URL die für die Web-API genutzt wird. Kann aktuell nur im Code des Moduls geändert werden.
- token
  Der Token, der bei der Anmeldung über die Web-API übergeben wurde und der für weitere Aufrufe übere die Web-API genutzt wird.
- token_expires
  Timestamp an den der Token abläuft und ein Reconnect erforderlich ist.
- user_id
  User-ID des über dei Web-API angemeldeten Users.

### eufyStation

Diese Modul steuert Stations oder integrierte Stations einer Kamera.

Aktuell werden folgenden Stations/Geräte unterstützt.

| Device_TYPE | NAME                     |
| ----------- | ------------------------ |
| 0           | HomeBase 2               |
| 30          | Indoor Camera            |
| 31          | Indoor Pan & Tilt Camera |

#### DEFINE

Normalerweise werden die Geräte per Auto-Create über das eufySecurity-Gerät angelegt. Bei Probleme kann das Gerät wie folgt auch manuell angelegt werden.

```
define <name> eufyStation <device_type> <serial_number>
```

- **<name>**
  Der Name des Gerätes **muss** das folgende Format haben:
  **eufyStation_**<serial_number>.
  Beispiel: eufyStation_T8010P2320180F8E
- <device_type>
  Einer der oben genannten Werte (0,30,31)
- <serial_number>
  Beispiel: T8010P2320180F8E

#### SET

- connect
  Aufbau einer P2P-Verbindung zu der Station
- disconnect
  Schließen der P2P-Verbindung zu der Station
- GuardMode
  Setzen des GuardMode für die Station

#### GET

- update
  Update der Daten der Station über die Web-API. Wurde noch keine Verbindung über die Web-API zuvor hergestellt, dann wird zuerst automatisch ein connect ausgeführt.

- DskKey

  Aktuell nur zum debugging implementiert. Sollte nicht genutzt werden! Entfällt in der finalen Version des Moduls.

#### ATTRIBUTES

- alias
  Wird beim Update automatisch mit dem Namen gesetzt, der in der Eufy-App für diese Station hinterlegt ist.

- userGuardModes
  Hier können benutzerspezifische GuardModes definiert werden. Der Aufbau ist "num:name". num ist eine Zahl, die über das Reading _guard_mode_ ermittelt werden kann. name ist ein benutzerspezifischer Name für diese Mode. Mehre Modes können durch ein ; getrennt werden.

  Beispiel: 4:Day;3:Night

  Über das Attribut können auch Default-Modes umbenannt werden. z.B. Hat HOME den Wert 1. Mittel "1:Zuhause" wird dann immer Zuhause statt HOME angezeigt.

#### READINGS

- create_time
  Zeitpunkt an dem dieses Gerät hergestellt/gebaut wurde(?)
- event_num
  Anzahl der Ereignisse, die die erkannt wurden (Alle Cams an einer Station, oder eine Cam mit integrierter Station)
- guard_mode
  Aktuell aktiver GuardMode
- ip_addr
  Bei einer HomeBase 2 die externe IP des Routers. Bei einer Indoor Cam mit integrierter Station die lokale IP im Heimnetz
- ip_addr_local
  Bei einer HomeBase 2 die lokale IP im Heimnetz
- main_hw_version
- main_sw_time
- main_sw_version
- p2p_did
- p2p_state
- sec_hw_version
- sec_sw_time
- sec_sw_version
- state
- station_id
- station_model
- time_zone
- update_time
- wifi_mac
- wifi_ssid

### eufyCamera

Das Modul ist für die Kameras zuständig. Aktuell sind für die Kameras keine sinnvollen Funktionen implementiert.

Es werden nur aktuelle Werte der Kamera als Reading dargestellt.

Aktuell werden folgenden Kameras unterstützt.

| Device_TYPE | NAME                     |
| ----------- | ------------------------ |
| 1           | Camera                   |
| 7           | Battery Doorbell         |
| 8           | eufyCam 2C               |
| 9           | eufyCam 2                |
| 30          | Indoor Camera 2k         |
| 31          | Indoor Pan & Tilt Camera |

#### DEFINE

Normalerweise werden die Geräte per Auto-Create über das eufySecurity-Gerät angelegt. Bei Probleme kann das Gerät wie folgt auch manuell angelegt werden.

```
define <name> eufyCamera <device_type> <serial_number>
```

- **<name>**
  Der Name des Gerätes **muss** das folgende Format haben:
  **eufyCamera_**<serial_number>.
  Beispiel: eufyStation_T8114P0220181D96 
- <device_type>
  Einer der oben genannten Werte (1,7,8,9,30,31)
- <serial_number>
  Beispiel: T8114P0220181D96

#### SET

#### GET

- update
  Update der Daten der Kamera über die Web-API. Wurde noch keine Verbindung über die Web-API zuvor hergestellt, dann wird zuerst automatisch ein connect ausgeführt.

#### ATTRIBUTES

- alias
  Wird beim Update automatisch mit dem Namen gesetzt, der in der Eufy-App für diese Station hinterlegt ist.

- icon
  Wird beim Define automatisch mit _it_camera_ vorbesetzt.

- room
  Wird beim Define automatisch mit _eufySecurity_ vorbesetzt.

- userReadings

  battery { ReadingsVal($NAME,"battery_level",0) > 10 ? "ok" : "low"}
  Das Reading battery wird automatisch beim Define angelegt. Damit kann der Akku der Kamera in eine automatische Überwachung der Batterien integriert werden.

#### READINGS

- battery
- battery_level
- create_time
- device_channel
- device_model
- device_type
- event_num
- main_hw_version
- main_sw_time
- sec_sw_time
- sec_sw_version
- state
- update_time
- wifiRSSI