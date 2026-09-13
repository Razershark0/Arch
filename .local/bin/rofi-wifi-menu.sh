#!/usr/bin/env bash
# Adapted from zbaylin/rofi-wifi-menu (github.com/zbaylin/rofi-wifi-menu):
# stripped the hardcoded font/width/position rofi options so it inherits
# this machine's themed ~/.config/rofi/config.rasi like every other rofi
# menu, instead of looking visually inconsistent with its own overrides.

FIELDS=SSID,SECURITY

LIST=$(nmcli --fields "$FIELDS" device wifi list | sed '/^--/d')
LINENUM=$(echo "$LIST" | wc -l)
KNOWNCON=$(nmcli connection show)
CONSTATE=$(nmcli -fields WIFI g)

CURRSSID=$(LANGUAGE=C nmcli -t -f active,ssid dev wifi | awk -F: '$1 ~ /^yes/ {print $2}')

if [[ -n $CURRSSID ]]; then
    HIGHLINE=$(echo "$(echo "$LIST" | awk -F "[  ]{2,}" '{print $1}' | grep -Fxn -m 1 "$CURRSSID" | awk -F ":" '{print $1}') + 1" | bc)
fi

if [ "$LINENUM" -gt 8 ] && [[ "$CONSTATE" =~ "enabled" ]]; then
    LINENUM=8
elif [[ "$CONSTATE" =~ "disabled" ]]; then
    LINENUM=1
fi

if [[ "$CONSTATE" =~ "enabled" ]]; then
    TOGGLE="toggle off"
elif [[ "$CONSTATE" =~ "disabled" ]]; then
    TOGGLE="toggle on"
fi

CHENTRY=$(echo -e "$TOGGLE\nmanual\n$LIST" | uniq -u | rofi -dmenu -p "Wi-Fi SSID: " -lines "$LINENUM" -a "$HIGHLINE")
CHSSID=$(echo "$CHENTRY" | sed 's/\s\{2,\}/\|/g' | awk -F "|" '{print $1}')

if [ "$CHENTRY" = "manual" ]; then
    MSSID=$(echo "enter the SSID of the network (SSID,password)" | rofi -dmenu -p "Manual Entry: " -lines 1)
    MPASS=$(echo "$MSSID" | awk -F "," '{print $2}')

    if [ "$MPASS" = "" ]; then
        nmcli dev wifi con "$MSSID"
    else
        nmcli dev wifi con "$MSSID" password "$MPASS"
    fi

elif [ "$CHENTRY" = "toggle on" ]; then
    nmcli radio wifi on

elif [ "$CHENTRY" = "toggle off" ]; then
    nmcli radio wifi off

else
    if [ "$CHSSID" = "*" ]; then
        CHSSID=$(echo "$CHENTRY" | sed 's/\s\{2,\}/\|/g' | awk -F "|" '{print $3}')
    fi

    if [[ $(echo "$KNOWNCON" | grep "$CHSSID") = "$CHSSID" ]]; then
        nmcli con up "$CHSSID"
    else
        if [[ "$CHENTRY" =~ "WPA2" ]] || [[ "$CHENTRY" =~ "WEP" ]]; then
            WIFIPASS=$(echo "if connection is stored, hit enter" | rofi -dmenu -p "password: " -lines 1)
        fi
        nmcli dev wifi con "$CHSSID" password "$WIFIPASS"
    fi
fi
