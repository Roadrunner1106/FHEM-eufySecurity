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
    31 => [ 'INDOOR_PT_CAMERA', 'Indoor Pan & Tilt Camera' ],
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

use constant CommandType2Num => {
    ARM_DELAY_AWAY                                => 1158,
    ARM_DELAY_CUS1                                => 1159,
    ARM_DELAY_CUS2                                => 1160,
    ARM_DELAY_CUS3                                => 1161,
    ARM_DELAY_HOME                                => 1157,
    AUTOMATION_DATA                               => 1278,
    AUTOMATION_ID_LIST                            => 1165,
    CMD_ALARM_DELAY_AWAY                          => 1167,
    CMD_ALARM_DELAY_CUSTOM1                       => 1168,
    CMD_ALARM_DELAY_CUSTOM2                       => 1169,
    CMD_ALARM_DELAY_CUSTOM3                       => 1170,
    CMD_ALARM_DELAY_HOME                          => 1166,
    CMD_AUDDEC_SWITCH                             => 1017,
    CMD_AUDIO_FRAME                               => 1301,
    CMD_BATCH_RECORD                              => 1049,
    CMD_BAT_DOORBELL_CHIME_SWITCH                 => 1702,
    CMD_BAT_DOORBELL_MECHANICAL_CHIME_SWITCH      => 1703,
    CMD_BAT_DOORBELL_QUICK_RESPONSE               => 1706,
    CMD_BAT_DOORBELL_SET_ELECTRONIC_RINGTONE_TIME => 1709,
    CMD_BAT_DOORBELL_SET_LED_ENABLE               => 1716,
    CMD_BAT_DOORBELL_SET_NOTIFICATION_MODE        => 1710,
    CMD_BAT_DOORBELL_SET_RINGTONE_VOLUME          => 1708,
    CMD_BAT_DOORBELL_UPDATE_QUICK_RESPONSE        => 1707,
    CMD_BAT_DOORBELL_VIDEO_QUALITY                => 1705,
    CMD_BAT_DOORBELL_WDR_SWITCH                   => 1704,
    CMD_BIND_BROADCAST                            => 1000,
    CMD_BIND_SYNC_ACCOUNT_INFO                    => 1001,
    CMD_BIND_SYNC_ACCOUNT_INFO_EX                 => 1054,
    CMD_CAMERA_INFO                               => 1103,
    CMD_CHANGE_PWD                                => 1030,
    CMD_CHANGE_WIFI_PWD                           => 1031,
    CMD_CLOSE_AUDDEC                              => 1018,
    CMD_CLOSE_DEV_LED                             => 1046,
    CMD_CLOSE_EAS                                 => 1016,
    CMD_CLOSE_IRCUT                               => 1014,
    CMD_CLOSE_PIR                                 => 1012,
    CMD_COLLECT_RECORD                            => 1047,
    CMD_CONVERT_MP4_OK                            => 1303,
    CMD_DECOLLECT_RECORD                          => 1048,
    CMD_DELLETE_RECORD                            => 1027,
    CMD_DEL_FACE_PHOTO                            => 1234,
    CMD_DEL_USER_PHOTO                            => 1232,
    CMD_DEVS_BIND_BROADCASE                       => 1038,
    CMD_DEVS_BIND_NOTIFY                          => 1039,
    CMD_DEVS_LOCK                                 => 1019,
    CMD_DEVS_SWITCH                               => 1035,
    CMD_DEVS_TO_FACTORY                           => 1037,
    CMD_DEVS_UNBIND                               => 1040,
    CMD_DEVS_UNLOCK                               => 1020,
    CMD_DEV_LED_SWITCH                            => 1045,
    CMD_DEV_PUSHMSG_MODE                          => 1252,
    CMD_DEV_RECORD_AUTOSTOP                       => 1251,
    CMD_DEV_RECORD_INTERVAL                       => 1250,
    CMD_DEV_RECORD_TIMEOUT                        => 1249,
    CMD_DOENLOAD_FINISH                           => 1304,
    CMD_DOORBELL_NOTIFY_PAYLOAD                   => 1701,
    CMD_DOORBELL_SET_PAYLOAD                      => 1700,
    CMD_DOOR_SENSOR_ALARM_ENABLE                  => 1506,
    CMD_DOOR_SENSOR_DOOR_EVT                      => 1503,
    CMD_DOOR_SENSOR_ENABLE_LED                    => 1505,
    CMD_DOOR_SENSOR_GET_DOOR_STATE                => 1502,
    CMD_DOOR_SENSOR_GET_INFO                      => 1501,
    CMD_DOOR_SENSOR_INFO_REPORT                   => 1500,
    CMD_DOOR_SENSOR_LOW_POWER_REPORT              => 1504,
    CMD_DOWNLOAD_CANCEL                           => 1051,
    CMD_DOWNLOAD_VIDEO                            => 1024,
    CMD_EAS_SWITCH                                => 1015,
    CMD_ENTRY_SENSOR_BAT_STATE                    => 1552,
    CMD_ENTRY_SENSOR_CHANGE_TIME                  => 1551,
    CMD_ENTRY_SENSOR_STATUS                       => 1550,
    CMD_FLOODLIGHT_BROADCAST                      => 902,
    CMD_FORMAT_SD                                 => 1029,
    CMD_FORMAT_SD_PROGRESS                        => 1053,
    CMD_GATEWAYINFO                               => 1100,
    CMD_GEO_ADD_USER_INFO                         => 1259,
    CMD_GEO_DEL_USER_INFO                         => 1261,
    CMD_GEO_SET_USER_STATUS                       => 1258,
    CMD_GEO_UPDATE_LOC_SETTING                    => 1262,
    CMD_GEO_UPDATE_USER_INFO                      => 1260,
    CMD_GET_ADMIN_PWD                             => 1122,
    CMD_GET_ALARM_MODE                            => 1151,
    CMD_GET_ARMING_INFO                           => 1107,
    CMD_GET_ARMING_STATUS                         => 1108,
    CMD_GET_AUDDEC_INFO                           => 1109,
    CMD_GET_AUDDEC_SENSITIVITY                    => 1110,
    CMD_GET_AUDDE_CSTATUS                         => 1111,
    CMD_GET_AWAY_ACTION                           => 1239,
    CMD_GET_BATTERY                               => 1101,
    CMD_GET_BATTERY_TEMP                          => 1138,
    CMD_GET_CAMERA_LOCK                           => 1119,
    CMD_GET_CHARGE_STATUS                         => 1136,
    CMD_GET_CUSTOM1_ACTION                        => 1148,
    CMD_GET_CUSTOM2_ACTION                        => 1149,
    CMD_GET_CUSTOM3_ACTION                        => 1150,
    CMD_GET_DELAY_ALARM                           => 1164,
    CMD_GET_DEVICE_PING                           => 1152,
    CMD_GET_DEVS_NAME                             => 1129,
    CMD_GET_DEVS_RSSI_LIST                        => 1274,
    CMD_GET_DEV_STATUS                            => 1131,
    CMD_GET_DEV_TONE_INFO                         => 1127,
    CMD_GET_DEV_UPGRADE                           => 1134,
    CMD_GET_EAS_STATUS                            => 1118,
    CMD_GET_EXCEPTION_LOG                         => 1124,
    CMD_GET_FLOODLIGHT_WIFI_LIST                  => 1405,
    CMD_GET_GATEWAY_LOCK                          => 1120,
    CMD_GET_HOME_ACTION                           => 1225,
    CMD_GET_HUB_LAN_IP                            => 1176,
    CMD_GET_HUB_LOG                               => 1132,
    CMD_GET_HUB_LOGIG                             => 1140,
    CMD_GET_HUB_NAME                              => 1128,
    CMD_GET_HUB_POWWER_SUPPLY                     => 1137,
    CMD_GET_HUB_TONE_INFO                         => 1126,
    CMD_GET_HUB_UPGRADE                           => 1133,
    CMD_GET_IRCUTSENSITIVITY                      => 1114,
    CMD_GET_IRMODE                                => 1113,
    CMD_GET_MDETECT_PARAM                         => 1105,
    CMD_GET_MIRRORMODE                            => 1112,
    CMD_GET_NEWVESION                             => 1125,
    CMD_GET_OFF_ACTION                            => 1177,
    CMD_GET_P2P_CONN_STATUS                       => 1130,
    CMD_GET_PIRCTRL                               => 1116,
    CMD_GET_PIRINFO                               => 1115,
    CMD_GET_PIRSENSITIVITY                        => 1117,
    CMD_GET_RECORD_TIME                           => 1104,
    CMD_GET_REPEATER_CONN_TEST_RESULT             => 1270,
    CMD_GET_REPEATER_RSSI                         => 1266,
    CMD_GET_REPEATER_SITE_LIST                    => 1263,
    CMD_GET_START_HOMEKIT                         => 1163,
    CMD_GET_SUB1G_RSSI                            => 1141,
    CMD_GET_TFCARD_FORMAT_STATUS                  => 1143,
    CMD_GET_TFCARD_REPAIR_STATUS                  => 1153,
    CMD_GET_TFCARD_STATUS                         => 1135,
    CMD_GET_UPDATE_STATUS                         => 1121,
    CMD_GET_UPGRADE_RESULT                        => 1043,
    CMD_GET_WAN_LINK_STATUS                       => 1268,
    CMD_GET_WAN_MODE                              => 1265,
    CMD_GET_WIFI_PWD                              => 1123,
    CMD_GET_WIFI_RSSI                             => 1142,
    CMD_HUB_ALARM_TONE                            => 1281,
    CMD_HUB_CLEAR_EMMC_VOLUME                     => 1800,
    CMD_HUB_NOTIFY_ALARM                          => 1282,
    CMD_HUB_NOTIFY_MODE                           => 1283,
    CMD_HUB_REBOOT                                => 1034,
    CMD_HUB_TO_FACTORY                            => 1036,
    CMD_IRCUT_SWITCH                              => 1013,
    CMD_KEYPAD_BATTERY_CAP_STATE                  => 1653,
    CMD_KEYPAD_BATTERY_CHARGER_STATE              => 1655,
    CMD_KEYPAD_BATTERY_TEMP_STATE                 => 1654,
    CMD_KEYPAD_GET_PASSWORD                       => 1657,
    CMD_KEYPAD_GET_PASSWORD_LIST                  => 1662,
    CMD_KEYPAD_IS_PSW_SET                         => 1670,
    CMD_KEYPAD_PSW_OPEN                           => 1664,
    CMD_KEYPAD_SET_CUSTOM_MAP                     => 1660,
    CMD_KEYPAD_SET_PASSWORD                       => 1650,
    CMD_LEAVING_DELAY_AWAY                        => 1172,
    CMD_LEAVING_DELAY_CUSTOM1                     => 1173,
    CMD_LEAVING_DELAY_CUSTOM2                     => 1174,
    CMD_LEAVING_DELAY_CUSTOM3                     => 1175,
    CMD_LEAVING_DELAY_HOME                        => 1171,
    CMD_LIVEVIEW_LED_SWITCH                       => 1056,
    CMD_MDETECTINFO                               => 1106,
    CMD_MOTION_SENSOR_BAT_STATE                   => 1601,
    CMD_MOTION_SENSOR_ENABLE_LED                  => 1607,
    CMD_MOTION_SENSOR_ENTER_USER_TEST_MODE        => 1613,
    CMD_MOTION_SENSOR_EXIT_USER_TEST_MODE         => 1610,
    CMD_MOTION_SENSOR_PIR_EVT                     => 1605,
    CMD_MOTION_SENSOR_SET_CHIRP_TONE              => 1611,
    CMD_MOTION_SENSOR_SET_PIR_SENSITIVITY         => 1609,
    CMD_MOTION_SENSOR_WORK_MODE                   => 1612,
    CMD_NAS_SWITCH                                => 1145,
    CMD_NAS_TEST                                  => 1146,
    CMD_NOTIFY_PAYLOAD                            => 1351,
    CMD_P2P_DISCONNECT                            => 1044,
    CMD_PING                                      => 1139,
    CMD_PIR_SWITCH                                => 1011,
    CMD_RECORDDATE_SEARCH                         => 1041,
    CMD_RECORDLIST_SEARCH                         => 1042,
    CMD_RECORD_AUDIO_SWITCH                       => 1366,
    CMD_RECORD_IMG                                => 1021,
    CMD_RECORD_IMG_STOP                           => 1022,
    CMD_RECORD_PLAY_CTRL                          => 1026,
    CMD_RECORD_VIEW                               => 1025,
    CMD_REPAIR_PROGRESS                           => 1058,
    CMD_REPAIR_SD                                 => 1057,
    CMD_REPEATER_RSSI_TEST                        => 1269,
    CMD_SDINFO                                    => 1102,
    CMD_SDINFO_EX                                 => 1144,
    CMD_SENSOR_SET_CHIRP_TONE                     => 1507,
    CMD_SENSOR_SET_CHIRP_VOLUME                   => 1508,
    CMD_SET_AI_NICKNAME                           => 1242,
    CMD_SET_AI_PHOTO                              => 1231,
    CMD_SET_AI_SWITCH                             => 1236,
    CMD_SET_ALL_ACTION                            => 1255,
    CMD_SET_ARMING                                => 1224,
    CMD_SET_ARMING_SCHEDULE                       => 1211,
    CMD_SET_AS_SERVER                             => 1237,
    CMD_SET_AUDDEC_INFO                           => 1212,
    CMD_SET_AUDDEC_SENSITIVITY                    => 1213,
    CMD_SET_AUDIOSENSITIVITY                      => 1227,
    CMD_SET_AUTO_DELETE_RECORD                    => 1367,
    CMD_SET_BITRATE                               => 1206,
    CMD_SET_CUSTOM_MODE                           => 1256,
    CMD_SET_DEVS_NAME                             => 1217,
    CMD_SET_DEVS_OSD                              => 1214,
    CMD_SET_DEVS_TONE_FILE                        => 1202,
    CMD_SET_DEV_MD_RECORD                         => 1273,
    CMD_SET_DEV_MIC_MUTE                          => 1240,
    CMD_SET_DEV_MIC_VOLUME                        => 1229,
    CMD_SET_DEV_SPEAKER_MUTE                      => 1241,
    CMD_SET_DEV_SPEAKER_VOLUME                    => 1230,
    CMD_SET_DEV_STORAGE_TYPE                      => 1228,
    CMD_SET_FLOODLIGHT_BRIGHT_VALUE               => 1401,
    CMD_SET_FLOODLIGHT_DETECTION_AREA             => 1407,
    CMD_SET_FLOODLIGHT_LIGHT_SCHEDULE             => 1404,
    CMD_SET_FLOODLIGHT_MANUAL_SWITCH              => 1400,
    CMD_SET_FLOODLIGHT_STREET_LAMP                => 1402,
    CMD_SET_FLOODLIGHT_TOTAL_SWITCH               => 1403,
    CMD_SET_FLOODLIGHT_WIFI_CONNECT               => 1406,
    CMD_SET_GSSENSITIVITY                         => 1226,
    CMD_SET_HUB_ALARM_AUTO_END                    => 1280,
    CMD_SET_HUB_ALARM_CLOSE                       => 1279,
    CMD_SET_HUB_AUDEC_STATUS                      => 1222,
    CMD_SET_HUB_GS_STATUS                         => 1220,
    CMD_SET_HUB_IRCUT_STATUS                      => 1219,
    CMD_SET_HUB_MVDEC_STATUS                      => 1221,
    CMD_SET_HUB_NAME                              => 1216,
    CMD_SET_HUB_OSD                               => 1253,
    CMD_SET_HUB_PIR_STATUS                        => 1218,
    CMD_SET_HUB_SPK_VOLUME                        => 1235,
    CMD_SET_IRMODE                                => 1208,
    CMD_SET_JSON_SCHEDULE                         => 1254,
    CMD_SET_LANGUAGE                              => 1200,
    CMD_SET_LIGHT_CTRL_BRIGHT_PIR                 => 1412,
    CMD_SET_LIGHT_CTRL_BRIGHT_SCH                 => 1413,
    CMD_SET_LIGHT_CTRL_LAMP_VALUE                 => 1410,
    CMD_SET_LIGHT_CTRL_PIR_SWITCH                 => 1408,
    CMD_SET_LIGHT_CTRL_PIR_TIME                   => 1409,
    CMD_SET_LIGHT_CTRL_SUNRISE_INFO               => 1415,
    CMD_SET_LIGHT_CTRL_SUNRISE_SWITCH             => 1414,
    CMD_SET_LIGHT_CTRL_TRIGGER                    => 1411,
    CMD_SET_MDETECTPARAM                          => 1204,
    CMD_SET_MDSENSITIVITY                         => 1272,
    CMD_SET_MIRRORMODE                            => 1207,
    CMD_SET_MOTION_SENSITIVITY                    => 1276,
    CMD_SET_NIGHT_VISION_TYPE                     => 1277,
    CMD_SET_NOTFACE_PUSHMSG                       => 1248,
    CMD_SET_PAYLOAD                               => 1350,
    CMD_SET_PIRSENSITIVITY                        => 1210,
    CMD_SET_PIR_INFO                              => 1209,
    CMD_SET_PIR_POWERMODE                         => 1246,
    CMD_SET_PIR_TEST_MODE                         => 1243,
    CMD_SET_PRI_ACTION                            => 1233,
    CMD_SET_RECORDTIME                            => 1203,
    CMD_SET_REPEATER_PARAMS                       => 1264,
    CMD_SET_RESOLUTION                            => 1205,
    CMD_SET_SCHEDULE_DEFAULT                      => 1257,
    CMD_SET_SNOOZE_MODE                           => 1271,
    CMD_SET_STORGE_TYPE                           => 1223,
    CMD_SET_TELNET                                => 1247,
    CMD_SET_TIMEZONE                              => 1215,
    CMD_SET_TONE_FILE                             => 1201,
    CMD_SET_UPGRADE                               => 1238,
    CMD_SNAPSHOT                                  => 1028,
    CMD_START_REALTIME_MEDIA                      => 1003,
    CMD_START_RECORD                              => 1009,
    CMD_START_REC_BROADCASE                       => 900,
    CMD_START_TALKBACK                            => 1005,
    CMD_START_VOICECALL                           => 1007,
    CMD_STOP_REALTIME_MEDIA                       => 1004,
    CMD_STOP_RECORD                               => 1010,
    CMD_STOP_REC_BROADCASE                        => 901,
    CMD_STOP_SHARE                                => 1023,
    CMD_STOP_TALKBACK                             => 1006,
    CMD_STOP_VOICECALL                            => 1008,
    CMD_STREAM_MSG                                => 1302,
    CMD_STRESS_TEST_OPER                          => 1050,
    CMD_TIME_SYCN                                 => 1033,
    CMD_UNBIND_ACCOUNT                            => 1002,
    CMD_VIDEO_FRAME                               => 1300,
    CMD_WIFI_CONFIG                               => 1032
};

my %Num2CommandType = reverse CommandType2Num;

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
        "1:eufyCamera"  => "^C:(1|7|8|9|30|31):.*",
        "2:eufyStation" => "^S:(0|31):.*"
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
    my $guard_mode;

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

sub eufySecurity_Get($$$@) {
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

# ----------------------------------------------------------------------------
# The read function is called automatically when data is received on a socket
# ----------------------------------------------------------------------------
sub eufySecurity_Read($) {
    my ($shash) = @_;    # ACHTUNG: Hier wird der Hash des Sockets übergeben und NICHT der Hash des Moduls!

    my $sock = $shash->{SOCKET};

    # Hash des Moduls
    my $parent = $shash->{PARENT};
    my $hash   = $defs{$parent};
    my $name   = $hash->{NAME};

    my $buffer;
    $sock->recv( $buffer, 1024 );

    if ( hasHeader( $buffer, ResponseMessageType->{PONG} ) ) {

        # nothing todo
        # responing to a PING from our side
        return;
    }
    elsif ( hasHeader( $buffer, ResponseMessageType->{PING} ) ) {

        # We have to answer with a PONG
        sendMessage( $sock, RequestMessageType->{PONG}, "" );
        return;
    }
    elsif ( hasHeader( $buffer, ResponseMessageType->{END} ) ) {

        Log3 $name, 3, "eufySecurity (Read) - receive END-Message, close connection";

        delete $selectlist{ $shash->{NAME} };
        $sock->close();
        $shash->{state} = 'disconnect';

        my ( $device_type, $station_sn ) = split( /_/, $shash->{NAME} );
        Dispatch( $hash, "S:$device_type:$station_sn:SET_P2P_STATE:disconnect" );
    }
    elsif ( hasHeader( $buffer, ResponseMessageType->{CAM_ID} ) ) {

        # Answer from the device to a CAM_CHECK message
        return;
    }
    elsif ( hasHeader( $buffer, ResponseMessageType->{ACK} ) ) {

        # receive ACK for a data telegram sent by us
        my $numAcks = unpack( 'n', substr( $buffer, 6, 2 ) );
        for ( my $i = 1 ; $i <= $numAcks ; $i++ ) {
            my $index      = 6 + $i * 2;
            my $ackedSeqNo = unpack( 'n', substr( $buffer, $index, 2 ) );
            Log3 $name, 3, "eufySecurity (Read) - receive ACK for seqNo $ackedSeqNo";
        }

        return;
    }
    elsif ( hasHeader( $buffer, ResponseMessageType->{DATA} ) ) {
        my $seqNo          = unpack( 'C', substr( $buffer, 6, 1 ) ) * 256 + unpack( 'C', substr( $buffer, 7, 1 ) );
        my $dataTypeBuffer = substr( $buffer, 4, 2 );
        my $dataType       = dataType2Name($dataTypeBuffer);

        # Test for duplicate
        return if ( ( defined $shash->{seenSeqNo}{$dataType} ) and ( $shash->{seenSeqNo}{$dataType} >= $seqNo ) );
        $shash->{seenSeqNo}{$dataType} = seqNo;
        Log3 $name, 3, "eufySecurity (Read) - receive DATA message: " . unpack( 'H*', $buffer );

        sendACK( $sock, $dataTypeBuffer, $seqNo );
        handleData( $shash, $hash, $seqNo, $dataType, $buffer );
        return;
    }
    else {
        #Todo Hier noch die Station ausgeben, von der das Telegram kommt
        Log3 $name, 3, "eufySecurity (Read) - unknown message type:" . unpack( 'H*', $buffer );
    }
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

        #Set hash to default values for P2P connection
        $hash->{P2P}{$sn}{NAME}           = $device_type . "_" . $sn;
        $hash->{P2P}{$sn}{PARENT}         = $name;
        $hash->{P2P}{$sn}{state}          = "disconnect";
        $hash->{P2P}{$sn}{local_ip}       = $args[0];
        $hash->{P2P}{$sn}{p2p_did}        = $args[1];
        $hash->{P2P}{$sn}{action_user_id} = $args[2];
        $hash->{P2P}{$sn}{directReadFn}   = \&eufySecurity_Read;

        Log3 $name, 3, "eufySecurity $name (Write) - connect to " . $args[0] . " p2p_did:" . $args[1] . " user_id:" . $args[2];

        # TBD Returnwert ist p2p_state der Verbindung (connect|disconnect|error)
        my $ret = p2p_connect( $hash, $sn );
        Dispatch( $hash, "S:$device_type:$sn:SET_P2P_STATE:$ret" );
    }
    elsif ( $cmd eq "DISCONNECT_STATION" ) {

        # Send END message to close the connect
        # The station also responds with an END message. The socket is then closed in
        # eufySecurity_Read when the message arrives
        sendMessage( $hash->{P2P}{$sn}{SOCKET}, ResponseMessageType->{END}, "" );
        Dispatch( $hash, "S:$device_type:$sn:SET_P2P_STATE:disconnect" );
    }
    elsif ( $cmd eq "GUARD_MODE" ) {
        my $guard_mode;
        if ( $args[0] eq 'Away' ) {
            $guard_mode = 0;
        }
        elsif ( $args[0] eq 'Home' ) {
            $guard_mode = 1;
        }
        elsif ( $args[0] eq 'Schedule' ) {
            $guard_mode = 2;
        }
        elsif ( $args[0] eq 'Geofencing' ) {
            $guard_mode = 47;
        }
        elsif ( $args[0] eq 'Disarmed' ) {
            $guard_mode = 63;
        }
        else {
            Log3 $name, 3, "eufySecurity $name (Set) - unknown GuardMode $guard_mode";
            return "unknown GuardMode $guard_mode";
        }
        Log3 $name, 3, "eufySecurity $name (Write) - set Guard Mode to " . $args[0] . "($guard_mode)";

        sendCommandWithInt( $hash, $sn, 1224, $guard_mode );
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
                  Dispatch( $hash, "S:" . $json->{data}[$i]{device_type} . ":" . $json->{data}[$i]{station_sn} . ":UPDATE" );
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
        Log3 $name, 3, "eufySecurity (getDevicesCB) - data: $data";

        ### Check if json can be parsed into hash
        eval {
            $json = decode_json( encode_utf8($data) );
            1;
        } or do {
            ### Log Entry for debugging purposes
            Log3 $name, 3, "eufySecurity (Callback getDevicess) - Error decode json";
            return "eufySecurity (getDevicesCN) - Error decode json";
        };

        if ( $json->{code} == 0 ) {
            for ( $i = 0 ; $i < @{ $json->{data} } ; $i++ ) {
                Log3 $name, 3, "eufySecurity (Callback getDevices) - camera: " . $json->{data}[$i]{device_sn};

                # Update Daten über (io_)hash an Kamera übergeben
                $hash->{helper}{UPDATE} = $json->{data}[$i];
                my $found =
                  Dispatch( $hash, "C:" . $json->{data}[$i]{device_type} . ":" . $json->{data}[$i]{device_sn} . ":UPDATE" );
                Log3 $name, 3, "eufySecurity (getDevicesCB) - found: $found";
            }
        }
        else {
            Log3 $name, 3, "eufySecurity (getDevicesCB) - eufy Security Fehler code: " . $json->{code} . " msg: " . $json->{msg};
        }

    }
    else {
        Log3 $name, 3, "eufySecurity (getDevicesCB) - HttpUtils Fehler $err";
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
sub p2p_connect($$) {
    my ( $hash, $station_sn ) = @_;
    my $local_ip   = $hash->{P2P}{$station_sn}{local_ip};
    my $local_port = 32108;
    my $buffer;

    # Send a lookup request to determine the port for further P2P connection
    my $sndsock = IO::Socket::INET->new(
        PeerAddr  => $local_ip,
        PeerPort  => $local_port,
        ReusePort => 1,
        Proto     => 'udp'
    );

    if ( !$sndsock ) {
        return "error: failed create sndSocket";
    }

    my $recvsock = IO::Socket::INET->new(
        Proto     => 'udp',
        LocalPort => $sndsock->sockport(),
        ReusAddr  => 1,
        ReusePort => 1,
        Timeout   => 3
    );

    if ( !$recvsock ) {
        return "error: failed create recvSocket";
    }

    my $payload = "\x00\x00";
    sendMessage( $sndsock, "\xf1\x30", $payload );
    $sndsock->close();

    $recvsock->recv( $buffer, 1024 );
    if ( hasHeader( $buffer, ResponseMessageType->{LOCAL_LOOKUP_RESP} ) ) {
        $hash->{P2P}{$station_sn}{p2p_did_hex} = substr( $buffer, 4, 17 );
    }

    $local_port = $recvsock->peerport;
    $recvsock->close();

    $hash->{P2P}{$station_sn}{local_port} = $local_port;

    # init connection
    $hash->{P2P}{$station_sn}{seq_nr} = 0;

    Log3 $name, 3, "eufySecurity $name (p2p_connect) - connect to ip:port ($local_ip:$local_port)";

    my $sock = IO::Socket::INET->new(
        PeerAddr  => $local_ip,
        PeerPort  => $local_port,
        ReusePort => 1,
        Proto     => 'udp',
    );

    if ( !$sock ) {
        return "error: failed create P2P socket";
    }

    sendMessage( $sock, RequestMessageType->{CHECK_CAM}, $hash->{P2P}{$station_sn}{p2p_did_hex} . "\x00\x00\x00\x00\x00\x00" );

    $sock->recv( $buffer, 1024 );
    $hash->{P2P}{$station_sn}{state} = 'connect';

    # Set infos for X_ReadFn to handle receiving pakages
    $hash->{P2P}{$station_sn}{SOCKET} = $sock;
    $hash->{P2P}{$station_sn}{FD}     = $sock->fileno();
    my $shash = $hash->{P2P}{$station_sn};

    $selectlist{ $shash->{'NAME'} } = $shash;

    return 'connect';
}

# ----------------------------------------------------------------------------
# Send a message over P2P
# ----------------------------------------------------------------------------
sub sendMessage($$$) {
    my ( $sock, $type, $payload ) = @_;

    my $payload_len = int2BE( length($payload) );
    my $message     = $type . $payload_len . $payload;

    # Log message unless the type is PONG
    Log3 $name, 3, "eufySecurity $name (sendMessage) - send message [" . unpack( 'H*', $message ) . "]" if $type ne RequestMessageType->{PONG};
    $sock->send($message);
}

# ----------------------------------------------------------------------------
# Send a Acknowledge over P2P
# ----------------------------------------------------------------------------
sub sendACK($$$) {
    my ( $sock, $dataType, $seqNo ) = @_;

    # numPendingAcks ist immer 1

    my $payload = $dataType . int2BE(1) . int2BE($seqNo);
    sendMessage( $sock, RequestMessageType->{ACK}, $payload );
}

sub sendCommandWithInt($$$$) {
    my ( $hash, $sn, $cmd_type, $value ) = @_;

    # Entspricht Funktion buildIntCommandPayload(value, this.actor) aus payload.utils.ts
    my $payload = "\x84\x00";
    $payload .= "\x00\x00\x01\x00\xff\x00\x00\x00";
    $payload .= pack( 'c', $value );                               # Value for comannd CMD_SET_ARMING
    $payload .= "\x00\x00\x00";
    $payload .= pack( 'A*', $hash->{P2P}{$sn}{action_user_id} );
    $payload .= "\x00" x 88;

    # Enspricht Funktion sendCommand aus device-client.service.ts
    my $seqNr = $hash->{P2P}{$sn}{seq_nr}++;

    # buildCommandHeader(msgSeqNumber, commandType);
    my $cmdHeader = "\xd1\x00" . int2BE($seqNr) . MAGIC_WORD . int2LE($cmd_type);
    my $data      = $cmdHeader . $payload;

    sendMessage( $hash->{P2P}{$sn}{SOCKET}, RequestMessageType->{DATA}, $data );
}

sub handleData($$$$$) {
    my ( $shash, $hash, $seqNo, $dataType, $buffer ) = @_;
    my $name = $hash->{NAME};

    if ( $dataType eq 'CONTROL' ) {
        parseDataControl( $shash, $hash, $seqNo, $buffer );
    }
    elsif ( $dataType eq 'DATA' ) {

        my $commandId = unpack( 'v', substr( $buffer, 12, 2 ) );
        my $data      = unpack( 'v', substr( $buffer, 24, 2 ) );
        Log3 $name, 3, "eufySecurity (handleData) - Data package with commandId: " . $num2CommandType->{$commandId} . " ($commandId) data: $data";
    }
    elsif ( $dataType eq 'BINARY' ) {

    }
    elsif ( $dataType eq 'VIDEO' ) {

    }
    else {
        Log3 $name, 3, "eufySecurity (handleData) - unknown data type: " . pack( 'H*', substr( $buffer, 4, 2 ) );
    }

}

sub parseDataControl($$$$) {
    my ( $shash, $hash, $seqNo, $buffer ) = @_;
    my $name = $hash->{NAME};
    my ( $device_type, $station_sn ) = split( /_/, $shash->{DEF} );

    if ( unpack( 'A*', substr( $buffer, 8, 4 ) ) eq MAGIC_WORD ) {
        my $commandId = unpack( 'v', substr( $buffer, 12, 2 ) );
        $hash->{P2P}{$station_sn}{ccmb}{commandId} = $commandId;

        my $bytesToRead = unpack( 'v', substr( $buffer, 14, 2 ) );
        $hash->{P2P}{$station_sn}{ccmb}{bytesToRead} = $bytesToRead;

        my $payload = substr( $buffer, 24 );
        $hash->{P2P}{$station_sn}{ccmb}{messages}[$seqNo] = $payload;
        $hash->{P2P}{$station_sn}{ccmb}{bytesRead} += length($payload);
    }
    else {
        my $payload = substr( $buffer, 8 );
        $hash->{P2P}{$station_sn}{ccmb}{messages}[$seqNo] = $payload;
        $hash->{P2P}{$station_sn}{ccmb}{bytesRead} += length($payload);
    }

    Log3 $name, 3,
        "eufySecurity (parseDataControl) bytesToRead:"
      . $hash->{P2P}{$station_sn}{ccmb}{bytesToRead}
      . " bytesRead:"
      . $hash->{P2P}{$station_sn}{ccmb}{bytesRead};

    if ( $hash->{P2P}{$station_sn}{ccmb}{bytesRead} >= $hash->{P2P}{$station_sn}{ccmb}{bytesToRead} ) {
        my $commandId       = $hash->{P2P}{$station_sn}{ccmb}{commandId};
        my @messages        = $hash->{P2P}{$station_sn}{ccmb}{messages};
        my $completeMessage = '';
        while ( @{ $hash->{P2P}{$station_sn}{ccmb}{messages} } ) {
            $completeMessage .= shift @{ $hash->{P2P}{$station_sn}{ccmb}{messages} };
            Log3 $name, 3, "eufySecurity (parseDataControl) completeMessage [" . unpack( 'H*', $completeMessage ) . "]";
        }

        delete $hash->{P2P}{$station_sn}{ccmb};

        handleDataControl( $shash, $hash, $commandId, $completeMessage );
    }
}

sub handleDataControl($$$$) {
    my ( $shash, $hash, $commandId, $message ) = @_;
    my $name = $hash->{NAME};
	my ($device_type, $station_sn) = split(/_/,$shash->{NAME});

    if ( $commandId eq CommandType2Num->{CMD_GET_ALARM_MODE} ) {
        my $guardMode = unpack( 'C', $message );
        Log3 $name, 3, "eufySecurity (handleDataControl) GuardMode is set to $guardMode";
		Dispatch($hash, "S:$device_type:$station_sn:SET_GUARDMODE:$guardMode");
    }
    elsif ( $commandId eq CommandType2Num->{CMD_CAMERA_INFO} ) {
        Log3 $name, 3, "eufySecurity (handleDataControl) Camera info: " . unpack( 'A*', $message );
		 $json = decode_json( encode_utf8($message) );
		 for ( $i = 0 ; $i < @{ $json->{params} } ; $i++ ) {
			 if ($json->{params}[$i]{param_type} == 1151) {
				 my $guardMode = $json->{params}[$i]{param_value};
			 	Dispatch($hash, "S:$device_type:$station_sn:SET_GUARDMODE:$guardMode");
			 }
		 }
    } else {
	    Log3 $name, 3, "eufySecurity (handleDataControl) Untreated message commandId: $commandId message [" . unpack( 'H*', $message ) . "]";
    }
}

# ----------------------------------------------------------------------------
# convert integer in two bytes, low byte first (Little-Endian-Format)
# ----------------------------------------------------------------------------
sub int2LE($) {
    my $value = shift;
    return pack( 'CC', $value % 256, int( $value / 256 ) );
}

# ----------------------------------------------------------------------------
# convert integer in two bytes, high byte first (Big-Endian-Format)
# ----------------------------------------------------------------------------
sub int2BE($) {
    my $value = shift;
    return pack( 'CC', int( $value / 256 ), $value % 256 );
}

# ----------------------------------------------------------------------------
# Return first two bytes of P2P Message
# ----------------------------------------------------------------------------
sub hasHeader($$) {
    my ( $msg, $type ) = @_;
    return substr( $msg, 0, 2 ) eq $type;
}

# ----------------------------------------------------------------------------
# Return dataType Name as String
# ----------------------------------------------------------------------------
sub dataType2Name($) {
    my $dataType = shift;

    if ( $dataType eq "\xd1\x00" ) {
        return "DATA";
    }
    elsif ( $dataType eq "\xd1\x01" ) {
        return "VIDEO";
    }
    elsif ( $dataType eq "\xd1\x02" ) {
        return "CONTROL";
    }
    elsif ( $dataType eq "\xd1\x03" ) {
        return "BINARY";
    }
    else {
        return "unknown";
    }
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
