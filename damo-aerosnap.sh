#!/bin/bash
#
# Based on a script found at
# http://icculus.org/pipermail/openbox/2013-January/007772.html
#
# Written by <damo> Sept 2015
#
# The script emulates aerosnap, using X window properties for values.
# Left and/or right screen margins can be specified
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
  geom=$(wmctrl -d|head -n1 | awk '{print $4}')
  screenW=${geom%x*}
  screenH=${geom#*x}
}

get_WM_FRAME_STRUT(){   # WM sets window frame and border sizes
                        # Titlebar height depends on fontsize of Active titlebar
    
    winFRAME_STRUT=$(xprop -id $WINDOW | grep "FRAME_STRUT" | awk -F "=" '{print $2}')
    winSTRUT=${winFRAME_STRUT//,/}
    STRUT_L=$(echo $winSTRUT | awk '{print $1}')
    STRUT_R=$(echo $winSTRUT | awk '{print $2}')
    STRUT_T=$(echo $winSTRUT | awk '{print $3}')

    winFRAME_EXTENTS=$(xprop -id $WINDOW | grep "FRAME_EXTENTS" | awk -F "=" '{print $2}')
    winEXTENTS=${winFRAME_EXTENTS//,/}
    EXT_L=$(echo $winEXTENTS | awk '{print $1}')
    EXT_R=$(echo $winEXTENTS | awk '{print $2}')
    EXT_T=$(echo $winEXTENTS | awk '{print $3}')
    
    Xoffset=$(( $EXT_L + $STRUT_L ))    # Need corrections for wmctrl
    Yoffset=$(( $EXT_T + $STRUT_T ))
    Woffset=$(( $EXT_R + $STRUT_R ))
}

store_geometry() {
    
    eval $(xdotool getactivewindow getwindowgeometry --shell)
    set_prop "_INITIAL_DIMENSION_X" $X
    set_prop "_INITIAL_DIMENSION_Y" $Y
    set_prop "_INITIAL_DIMENSION_WIDTH" $WIDTH
    set_prop "_INITIAL_DIMENSION_HEIGHT" $HEIGHT
    
    get_WM_FRAME_STRUT  # Get frame and border sizes
    
    set_prop "_OFFSET_X" $Xoffset
    set_prop "_OFFSET_W" $Woffset
    
    # Use different corrections if window is decorated/undecorated
    if xprop -id $WINDOW | grep -q _OB_WM_STATE_UNDECORATED ;then
        OFFSET_Y=$(($STRUT_T + $EXT_T ))
    else
        OFFSET_Y=$Yoffset
    fi
    set_prop "_OFFSET_Y" $OFFSET_Y
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
    
}

restore_dimension_geometry() {
    Xpos=$((initial_x-adjust_X))    # Correct for frame and border values
    Ypos=$((initial_y-adjust_Y))

    wmctrl -r :ACTIVE: -b remove,maximized_vert && \
    wmctrl -r :ACTIVE: -e 0,$Xpos,$Ypos,$initial_width,$initial_height

    xprop -id $WINDOW -remove _INITIAL_DIMENSION_X  # Clear X window properties
    xprop -id $WINDOW -remove _INITIAL_DIMENSION_Y
    xprop -id $WINDOW -remove _INITIAL_DIMENSION_WIDTH
    xprop -id $WINDOW -remove _INITIAL_DIMENSION_HEIGHT
    xprop -id $WINDOW -remove _OFFSET_X
    xprop -id $WINDOW -remove _OFFSET_Y
    xprop -id $WINDOW -remove _OFFSET_W
}

snap_left(){
    MARGIN_L=$1
    WIN_WIDTH_L=$((($screenW / 2 ) - ($MARGIN_L - $EXT_L) - $adjust_W ))
    
    wmctrl -r :ACTIVE: -b add,maximized_vert && \
    wmctrl -r :ACTIVE: -b remove,maximized_horz && \
    wmctrl -r :ACTIVE: -e 0,$MARGIN_L,0,$WIN_WIDTH_L,-1
}

snap_right(){
    MARGIN_R=$1
    WIN_WIDTH_R=$((($screenW / 2 ) - $MARGIN_R - $adjust_W ))
    
    wmctrl -r :ACTIVE: -b add,maximized_vert && \
    wmctrl -r :ACTIVE: -b remove,maximized_horz && \
    wmctrl -r :ACTIVE: -e 0,$((($screenW / 2 ) + $adjust_W )),0,$WIN_WIDTH_R,-1
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

    #for arg in "$@";do
        #case "$arg" in
            #-h|--help   )   echo "$USAGE"
                            #echo
                            #exit 0
                            #;;
            #-l|--left   )   if [[ $2 ]];then
                                #snap_left $2
                            #else
                                #snap_left
                            #fi
                            #;;
            #-r|--right  )   if [[ $2 ]];then
                                #snap_right $2
                            #else
                                #snap_right
                            #fi
                            #;;
            #*           )   if ! [[ $arg ]];then
                                #echo "$USAGE"
                                #echo
                                #exit 1
                            #fi
                            #;;
        #esac
    #done

