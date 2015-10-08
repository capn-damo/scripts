#!/bin/bash
##
## Logout/Exit dialog, using 'yad`
## Written for BunsenLabs Linux by damo <damo@bunsenlabs.org> October 2015
##
## TODO?    Confirm action
##
## Bug?: Accelerator keys may not display, depending on the gtk theme
##
########################################################################

USAGE="\n\texit-yad.sh [OPTION]\n\n\
\tWith no arg then run gui logout dialog\n\n\
\t-h|--help\tThis USAGE help\n\
\t--logout\tOpenbox logout\n\
\t--suspend\tSystem suspend\n\
\t--reboot\tSystem restart\n\
\t--poweroff\tShutdown system\n"

dbus_send="dbus-send --print-reply --system --dest=org.freedesktop.login1 /org/freedesktop/login1 org.freedesktop.login1.Manager.{} boolean:true"


if [[ -z $@ ]];then
    DIALOG=$(yad --undecorated --center --on-top\
        --window-icon="gtk-quit"\
        --text="Logout $USER?\tChoose an option..."\
        --text-align=center\
        --button="gtk-cancel:1" \
        --button="_Logout":2 \
        --button="_Suspend":3 \
        --button="_Reboot":4\
        --button="_Power Off":5 \
        )
    RET=$?
else
    case $@ in
        -h|--help)  echo -e "$USAGE"
                    exit 0;;
        --logout)   openbox --exit;;
        --suspend)  dbus_send suspend;;
        --reboot)   dbus_send reboot;;
        --poweroff) dbus_send poweroff;;
        *)          echo -e "\nUse a valid command arg..."
                    echo -e "$USAGE"
                    exit 1;;
    esac
fi

case $RET in
    1) exit 0;;
    2) cmd="openbox --exit";;
    3) cmd="dbus_send suspend";;
    4) cmd="dbus_send reboot" ;;
    5) cmd="dbus_send poweroff";;
    *) exit 1;;
esac

eval exec $cmd
