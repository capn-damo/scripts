#!/bin/bash
#
# Based on a script found at
# http://icculus.org/pipermail/openbox/2013-January/007772.html
#
# Written by <damo> Sept 2015
#
# The script emulates aerosnap, using X window properties for getting and storing values.
# Left and/or right screen margins can be specified;
# Works with dual monitors - windows will snap to edges of monitor they are on;
# Honours user-defined Openbox left and right screen margins;
# Works with decorated and undecorated windows, and windows with no borders.
#
# TODO: window widths for some terminals too narrow with left snapping

########################################################################

USAGE=$(echo -e "\vUSAGE:\tdamo-aerosnap.sh [--help|--left|--right] <margin>"
        echo -e "\v--help \t\tUsage"
        echo -e "--left \t\taerosnap to left screen edge"
        echo -e "--right \taerosnap to right screen edge"
        echo
        echo -e "If no margin is specified, the left and right values set for Openbox in rc.xml are used."
        echo 
        echo -e "The active window will snap to the edge of the screen on which it placed"
)

####    FUNCTIONS   ####################################################

set_prop() {    # Add var values to X window properties
  propname="$1"
  val="$2"
  xprop -id "$WINDOW" -f "$propname" 32i -set "$propname" "$val"
}

get_prop() {    # Retrieve var values using xprop
  propname="$1"
  varname="$2"
  eval "$varname"=$(xprop -id $WINDOW $propname | awk '{print $3}')
}

get_screen_dimensions() {
    desktopW=$(xrandr -q | grep Screen | awk '{print $8}')  # total desktop width
    geom=$(xdotool getdisplaygeometry)                      # geometry of current display
    screenW=${geom%' '*}
    # X position of active window:
    WINPOS=$(xwininfo -id $(xdotool getactivewindow) | grep "Absolute upper-left X" | awk '{print $NF}')
    
    if [[ "$WINPOS" -gt "$screenW" ]];then
        X_zero=$(( $desktopW - $screenW ))  # window is on R monitor
    else
        X_zero=0                            # window is on L monitor
    fi
}

get_WM_FRAME(){   # WM sets window frame and border sizes
                        # Titlebar height depends on fontsize of Active titlebar
    # get borders set by WM
    winFRAME_EXTENTS=$(xprop -id $WINDOW | grep "_NET_FRAME_EXTENTS" | awk -F "=" '{print $2}')
    winEXTENTS=${winFRAME_EXTENTS//,/}
    BORDER_L=$(echo $winEXTENTS | awk '{print $1}')
    BORDER_R=$(echo $winEXTENTS | awk '{print $2}')
    BORDER_T=$(echo $winEXTENTS | awk '{print $3}')
    BORDER_B=$(echo $winEXTENTS | awk '{print $4}')
    
    Xoffset=$(( $BORDER_L + $BORDER_R ))    # Need corrections for wmctrl
    Yoffset=$(( $BORDER_T + $BORDER_B ))
}

get_OB_margins() {
    RC="$HOME/.config/openbox/rc.xml"
    if [[ -f "$RC" ]]&>/dev/null;then
        tag="margins"
        RCXML=$(sed -n "/<$tag>/,/<\/$tag>/p" "$RC")
        OB_LEFT=$(grep -oPm1 "(?<=<left>)[^<]+" <<< "$RCXML")
        OB_RIGHT=$(grep -oPm1 "(?<=<right>)[^<]+" <<< "$RCXML")
    else
        echo "$RC not found"
        exit 1
    fi
}

store_geometry() {  # store values in X window properties
    eval $(xdotool getactivewindow getwindowgeometry --shell)

    set_prop "_INITIAL_DIMENSION_X" "$X"
    set_prop "_INITIAL_DIMENSION_Y" "$Y"
    set_prop "_INITIAL_DIMENSION_WIDTH" "$WIDTH"
    set_prop "_INITIAL_DIMENSION_HEIGHT" "$HEIGHT"
    
    get_WM_FRAME  # Get frame and border sizes
    set_prop "_OB_BORDER_L" "$BORDER_L"
    set_prop "_OB_BORDER_R" "$BORDER_R"
    set_prop "_OB_BORDER_T" "$BORDER_T"
    set_prop "_OB_BORDER_B" "$BORDER_B"
    set_prop "_OFFSET_X" "$Xoffset"
    
    # Use different corrections if window is decorated/undecorated
    if xprop -id $WINDOW | grep -q _OB_WM_STATE_UNDECORATED ;then
        OFFSET_Y="$Yoffset"
    else
        OFFSET_Y=$(( $BORDER_T * 2 ))
    fi
    set_prop "_OFFSET_Y" "$OFFSET_Y"
    
    get_OB_margins
    set_prop "_OB_MARGIN_L" "$OB_LEFT"
    set_prop "_OB_MARGIN_R" "$OB_RIGHT"
}

load_stored_geometry() {
    local tmp
    get_prop "_INITIAL_DIMENSION_X" "tmp"
    # xprop doesn't return an error code and has two different possible errors
    [[ $tmp == "such" || $tmp == "found." ]] && return 1
    initial_x=$tmp
    get_prop "_INITIAL_DIMENSION_Y" "initial_y"
    get_prop "_INITIAL_DIMENSION_WIDTH" "initial_width"
    get_prop "_INITIAL_DIMENSION_HEIGHT" "initial_height"
    get_prop "_OFFSET_X" "adjust_X"
    get_prop "_OFFSET_Y" "adjust_Y"
    get_prop "_OB_BORDER_L" "OB_border_left"
    get_prop "_OB_BORDER_R" "OB_border_right"
    get_prop "_OB_BORDER_T" "OB_border_top"
    get_prop "_OB_BORDER_B" "OB_border_bottom"
    get_prop "_OB_MARGIN_L" "OB_margin_left"
    get_prop "_OB_MARGIN_R" "OB_margin_right"
    
}

restore_dimension_geometry() {
    Xpos=$(( initial_x - adjust_X ))    # Correct for frame and border values
    Ypos=$(( initial_y - adjust_Y ))

    wmctrl -r :ACTIVE: -b remove,maximized_vert && \
    wmctrl -r :ACTIVE: -e 0,"$Xpos","$Ypos","$initial_width","$initial_height"

    xprop -id $WINDOW -remove _INITIAL_DIMENSION_X  # Clear X window properties
    xprop -id $WINDOW -remove _INITIAL_DIMENSION_Y
    xprop -id $WINDOW -remove _INITIAL_DIMENSION_WIDTH
    xprop -id $WINDOW -remove _INITIAL_DIMENSION_HEIGHT
    xprop -id $WINDOW -remove _OFFSET_X
    xprop -id $WINDOW -remove _OFFSET_Y
    xprop -id $WINDOW -remove _OB_BORDER_L
    xprop -id $WINDOW -remove _OB_BORDER_R
    xprop -id $WINDOW -remove _OB_BORDER_T
    xprop -id $WINDOW -remove _OB_BORDER_B
    xprop -id $WINDOW -remove _OB_MARGIN_L
    xprop -id $WINDOW -remove _OB_MARGIN_R
}

snap_left(){
    if [[ "$1" != 0 ]];then
        if [[ "$1" -lt "$OB_border_left" ]];then
            XPOS=$(( $OB_border_left + $X_zero ))    # don't need OB margin
        else
            XPOS=$(( $1 + $OB_border_left + $X_zero ))
        fi
    else
        XPOS=$(( $OB_margin_left + $X_zero ))  # add OB margin
    fi
    
    WIN_WIDTH_L=$((( $screenW / 2 ) - $XPOS - $adjust_X + $X_zero ))
    # Move window
    wmctrl -r :ACTIVE: -b add,maximized_vert && \
    wmctrl -r :ACTIVE: -b remove,maximized_horz && \
    wmctrl -r :ACTIVE: -e 0,"$XPOS",0,"$WIN_WIDTH_L",-1
}

snap_right(){
    if [[ "$1" != 0 ]];then
        if [[ "$1" -lt "$OB_border_right" ]];then
            MARGIN_R="$OB_border_right"    # don't need OB margin
        else
            MARGIN_R=$(( $1 + $OB_border_right ))
        fi
    else
        MARGIN_R="$OB_margin_right"  # add OB margin to right edge
    fi
    
    XPOS=$((( $screenW / 2 ) + $X_zero ))
    # Move window
    WIN_WIDTH_R=$((( $screenW / 2 ) - $MARGIN_R - $adjust_X ))
    wmctrl -r :ACTIVE: -b add,maximized_vert && \
    wmctrl -r :ACTIVE: -b remove,maximized_horz && \
    wmctrl -r :ACTIVE: -e 0,"$XPOS",0,"$WIN_WIDTH_R",-1
}

####    END FUNCTIONS   ################################################

if [[ $1 = "--help" ]] || ! [[ $@ ]];then
    echo "$USAGE"
    echo
    exit
fi

WINDOW=$(xdotool getactivewindow)
get_screen_dimensions
load_stored_geometry
    
err=$?
if [[ $err -ne 0 ]]; then   
    store_geometry
    get_prop "_OFFSET_X" "adjust_X"
    get_prop "_OFFSET_Y" "adjust_Y"
    get_prop "_OB_BORDER_L" "OB_border_left"
    get_prop "_OB_BORDER_R" "OB_border_right"
    get_prop "_OB_BORDER_T" "OB_border_top"
    get_prop "_OB_BORDER_B" "OB_border_bottom"
    get_prop "_OB_MARGIN_L" "OB_margin_left"
    get_prop "_OB_MARGIN_R" "OB_margin_right"
    
    if [[ $2 ]];then
        MARGIN="$2"
    else
        MARGIN=0
    fi
    if [[ $1 = "--left" ]];then
        snap_left "$MARGIN"
    elif [[ $1 = "--right" ]];then
        snap_right "$MARGIN"
    fi
else
  restore_dimension_geometry
fi



