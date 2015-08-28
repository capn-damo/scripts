#!/bin/bash
#
# Based on a script found at
# http://icculus.org/pipermail/openbox/2013-January/007772.html
#
# Written by <damo> Sept 2015
#
# The script emulates aerosnap, using X window properties for values.
# Left and/or right screen margins can be specified
# Works with dual monitors - windows will snap to edges of monitor they are on
#
# TODO: Honour user-defined Openbox screen margins
#
########################################################################

USAGE=$(echo -e "\vUSAGE:\tsnapping.sh [OPTION] <margin>"
        echo -e "\v--help \t\tUsage"
        echo -e "--left \t\taerosnap to left screen edge"
        echo -e "--right \taerosnap to right screen edge"
        echo
        echo -e "If no margin is specified, a value of 0 is used"
)

####    FUNCTIONS   ####################################################

set_prop() {    # Add var values to X window properties
  propname=$1
  val=$2

  xprop -id $WINDOW -f $propname 32i -set $propname $val
}

get_prop() {    # Retrieve var values using xprop
  propname=$1
  varname=$2
  eval $varname=$(xprop -id $WINDOW $propname|awk '{print $3}')
}

get_screen_dimensions() {
    desktopW=$(xrandr -q | grep Screen | awk '{print $8}')  # total desktop width
    geom=$(xdotool getdisplaygeometry)                      # geometry of current display
    screenW=${geom%' '*}
    screenH=${geom#*' '}
    # X position of active window
    WINPOS=$(xwininfo -id $(xdotool getactivewindow) | grep "Absolute upper-left X" | awk '{print $NF}')
    
    if [[ $WINPOS -gt $screenW ]];then
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
    Woffset=$(( $BORDER_L + $BORDER_R ))
}

get_OB_margins() {
    RC=".config/openbox/rc.xml"
    tag="margins"
    RCXML=$(sed -n "/<$tag>/,/<\/$tag>/p" "$RC")
    OB_LEFT=$(grep -oPm1 "(?<=<left>)[^<]+" <<< "$RCXML")
    OB_RIGHT=$(grep -oPm1 "(?<=<right>)[^<]+" <<< "$RCXML")
    #OB_TOP=$(grep -oPm1 "(?<=<top>)[^<]+" <<< "$RCXML")
    #OB_BOTTOM=$(grep -oPm1 "(?<=<bottom>)[^<]+" <<< "$RCXML")
}

store_geometry() {  # store values in X window properties
    eval $(xdotool getactivewindow getwindowgeometry --shell)

    set_prop "_INITIAL_DIMENSION_X" $X
    set_prop "_INITIAL_DIMENSION_Y" $Y
    set_prop "_INITIAL_DIMENSION_WIDTH" $WIDTH
    set_prop "_INITIAL_DIMENSION_HEIGHT" $HEIGHT
    
    get_WM_FRAME  # Get frame and border sizes
    
    set_prop "_OFFSET_X" $Xoffset
    set_prop "_OFFSET_W" $Woffset
    
    # Use different corrections if window is decorated/undecorated
    if xprop -id $WINDOW | grep -q _OB_WM_STATE_UNDECORATED ;then
        OFFSET_Y=$(( $BORDER_T + $BORDER_B ))
    else
        OFFSET_Y=$Yoffset
    fi
    set_prop "_OFFSET_Y" $OFFSET_Y
    
    get_OB_margins
    set_prop "_OB_MARGIN_LEFT" $OB_LEFT
    set_prop "_OB_MARGIN_RIGHT" $OB_RIGHT
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
    get_prop "_OFFSET_W" "adjust_W"
    get_prop "_OB_MARGIN_LEFT" "OB_margin_left"
    get_prop "_OB_MARGIN_RIGHT" "OB_margin_right"
    
}

restore_dimension_geometry() {
    Xpos=$(( initial_x - adjust_X ))    # Correct for frame and border values
    Ypos=$(( initial_y - adjust_Y ))

    wmctrl -r :ACTIVE: -b remove,maximized_vert && \
    wmctrl -r :ACTIVE: -e 0,$Xpos,$Ypos,$initial_width,$initial_height

    xprop -id $WINDOW -remove _INITIAL_DIMENSION_X  # Clear X window properties
    xprop -id $WINDOW -remove _INITIAL_DIMENSION_Y
    xprop -id $WINDOW -remove _INITIAL_DIMENSION_WIDTH
    xprop -id $WINDOW -remove _INITIAL_DIMENSION_HEIGHT
    xprop -id $WINDOW -remove _OFFSET_X
    xprop -id $WINDOW -remove _OFFSET_Y
    xprop -id $WINDOW -remove _OFFSET_W
    xprop -id $WINDOW -remove _OB_MARGIN_LEFT
    xprop -id $WINDOW -remove _OB_MARGIN_RIGHT
}

snap_left(){
    if [[ $1 != 0 ]];then
        XPOS=$(( $1 + $X_zero ))    # don't need OB margin
    else
        XPOS=$(( $OB_margin_left + $X_zero ))  # add OB margin
    fi
    
    WIN_WIDTH_L=$((( $screenW / 2 ) - ( $XPOS - $BORDER_L ) - $adjust_W + $X_zero ))
    
    wmctrl -r :ACTIVE: -b add,maximized_vert && \
    wmctrl -r :ACTIVE: -b remove,maximized_horz && \
    wmctrl -r :ACTIVE: -e 0,$XPOS,0,$WIN_WIDTH_L,-1
}

snap_right(){
    
    if [[ $1 != 0 ]];then
        MARGIN_R=$1    # don't need OB margin
    else
        MARGIN_R=$OB_margin_right  # add OB margin to right edge
    fi

    XPOS=$((( $screenW / 2 ) + $adjust_W + $X_zero ))
    WIN_WIDTH_R=$((( $screenW / 2 ) - $MARGIN_R - $adjust_W ))
    
    wmctrl -r :ACTIVE: -b add,maximized_vert && \
    wmctrl -r :ACTIVE: -b remove,maximized_horz && \
    wmctrl -r :ACTIVE: -e 0,$XPOS,0,$WIN_WIDTH_R,-1
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
    get_prop "_OFFSET_W" "adjust_W"
    
    if [[ $2 ]];then
        MARGIN=$2
    else
        MARGIN=0
    fi
    if [[ $1 = "--left" ]];then
        snap_left $MARGIN
    elif [[ $1 = "--right" ]];then
        snap_right $MARGIN
    fi
else
  restore_dimension_geometry
fi


