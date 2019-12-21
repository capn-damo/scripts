#!/bin/bash
##
## imgbb.sh
################### imgur.sh ###########################################
# Take screenshots and upload them to imgbb.
#
# Credentials for an account can be set up.
#
# Settings (settings.conf) file is created in $HOME/.config/imgbb
#
# The script returns BB-Code for the direct image link, and a linked thumbnail.
# YAD dialogs are used for user interaction.
#
########################################################################
# Copyright (C) 2019 damo   <damo@bunsenlabs.org>
#    This program is free software: you can redistribute it and/or modify
#    it under the terms of the GNU General Public License as published by
#    the Free Software Foundation, either version 3 of the License, or
#    (at your option) any later version.
#
#    This program is distributed in the hope that it will be useful,
#    but WITHOUT ANY WARRANTY; without even the implied warranty of
#    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#    GNU General Public License for more details.
#
#    You should have received a copy of the GNU General Public License
#    along with this program.  If not, see <http://www.gnu.org/licenses/>.
########################################################################
#
### REQUIRES:  yad, jq, xprop, wmctrl, wget, curl, scrot, xdotool,
#               convert(in imagemagick package), gio(in gvfs package)
#
########################################################################

URL="https://api.imgbb.com/1/upload"
export API_URL="https://api.imgbb.com/"   # used by run_browser()

export BL_YAD_INCLUDES='/usr/lib/bunsen/common/yad-includes' 
USR_CFG_DIR="$HOME/.config/imgbb"
SETTINGS_FILE="${USR_CFG_DIR}/settings.conf"
SCRIPT=$(basename "$0")
export IMG_VIEWER="x-www-browser"   # used by show_image()

#### YAD ###
DIALOG="yad --center --borders=20 --window-icon=distributor-logo-bunsenlabs --fixed"
TITLE="--title=Image BBCode"
T="--text="
DELETE="--button=Delete:2"
CLOSE="--button=gtk-close:1"
CANCEL="--button=gtk-cancel:1"
OK="--button=OK:0"

### required programs ###
declare -a APPS
APPS=( "yad" "xprop" "wmctrl" "wget" "curl" "scrot" "gio" "xdotool" "convert" )

### FUNCTIONS  #########################################################
### Get script args ###
function getargs(){
    while [[ ${#} != 0 ]]; do
        case "$1" in
            -h | --help)    echo -e "\n${USAGE}\n"
                            exit 0
                            ;;
            -s | --select)  SCROT="${SCREENSHOT_SELECT_COMMAND}"
                            ;;
            -w | --window)  SCROT="${SCREENSHOT_WINDOW_COMMAND}"
                            ;;
            -f | --full)    SCROT="${SCREENSHOT_FULL_COMMAND}"
                            ;;
            -d | --delay)   if [[ $2 != ?(-)+([0-9]) ]];then
                                message="\n\tDelay value must be an integer\n\tExiting script...\n"
                                echo -e "${message}"
                                yad_error "${message}"
                                exit 1
                            else
                                DELAY="$2"
                            fi
                            shift
                            ;;
            --file)         FNAME="$2"
                            shift
                            F_FLAG=1
                            ;;
                         *) message="\n\tFailed to parse options\n\tExiting script...\n"
                            echo -e "${message}" >&2
                            yad_error "${message}"
                            exit 1
                            ;;
        esac || { echo "Failed to parse options" >&2 && exit 1; }
        shift
    done
}
### Initialize settings.conf config  ###
function settings_conf(){
    ! [[ -d "${USR_CFG_DIR}" ]] && mkdir -p "${USR_CFG_DIR}" 2>/dev/null

    if ! [[ -f "${SETTINGS_FILE}" ]] 2>/dev/null;then
        touch "${SETTINGS_FILE}" && chmod 600 "${SETTINGS_FILE}"
        cat <<EOF > "${SETTINGS_FILE}"
### IMGUR SCREENSHOT DEFAULT CONFIG ####
### Read by ${SCRIPT} ###################
# Most of these settings can be overridden with script args

# Imgbb settings
CLIENT_API_KEY=""
IMG_VIEWER=""

# Local file settings
# User directory to save image:
FILE_DIR="$(xdg-user-dir PICTURES)"
FILE_NAME="imgur-%Y_%m_%d-%H:%M:%S"
# possible formats are png | jpg | tif | gif | bmp | webp
FILE_FORMAT="jpg"   

# Screenshot scrot commands
SCREENSHOT_SELECT_COMMAND="scrot -s "
SCREENSHOT_WINDOW_COMMAND="scrot -u -b "
SCREENSHOT_FULL_COMMAND="scrot "

EOF
    fi
    source "${SETTINGS_FILE}"
}
### Check required programs are installed ###
function check_required(){
    local message
    declare -a BAD_APPS # array to hold missing commands
    APPS+=( "${VIEWER}" )
    
    for app in "${APPS[@]}";do
        if type "${app}" >/dev/null 2>&1;then
            continue
        else
            echo >&2 "${app} not installed."
            BAD_APPS+=( "${app}" )
        fi
    done
    
    if (( ${#BAD_APPS[@]} > 0 ));then
        message="\n  You need to install\n"
        for app in "${BAD_APPS[@]}";do
            message="${message}  "\'"${app}"\'","
        done
        message="${message}\n  before proceeding.\n"
        echo -e "${message}"
        yad_error "${message}"
        exit
    fi
}

### File and Image functions ###
function getimage(){
    local message ret
    
    if ! [[ -z ${DELAY} ]] 2>/dev/null && ! [[ ${SCROT} == "${SCREENSHOT_SELECT_COMMAND}" ]] 2>/dev/null;then
        SCROT="${SCROT} -d ${DELAY} "
        message="\n\tNo image file provided...\n\tProceed with screenshot?\n \
        \n\tThere will be a pause of ${DELAY}s, to select windows etc\n"
    else
        SCROT="${SCROT} -d 1 "   # need a pause so YAD dialog can leave the scene
        message="\n\tNo image file provided...\n\tProceed with screenshot?\n"
    fi

    if [[ -z "$1" ]] 2>/dev/null; then
        yad_common_args+=("--image=dialog-question")
        yad_question "${message}"
        ret="$?"
        yad_common_args+=("--image=0")
        
        yad_common_args+=("--image=dialog-info")
        if (( ret == 1 ));then
            exit 0
        elif (( ret == 0 )) && [[ ${SCROT} == *"-s"* ]];then            # scrot command contains "-s"
            yad_info "\n\tDrag cursor to select area for screenshot\n"  # to select area
        elif (( ret == 0 )) && [[ ${SCROT} == *"-u"* ]];then            # scrot command contains "-u" 
            yad_info "\n\tSelect window to be Active, then click 'OK'\n" #for active window
        fi
        yad_common_args+=("--image=0")

        # new filename with date
        img_file="$(date +"${FILE_NAME}.${FILE_FORMAT}")"
        img_file="${FILE_DIR}/${img_file}" && export img_file
        take_screenshot "${img_file}"
    else
        # upload file instead of screenshot
        img_file="$1"
    fi
    
    # check if file exists
    if ! [[ -f "${img_file}" ]] 2>/dev/null; then
        message="\n\tfile '${img_file}' doesn't exist!\n\n\tExiting script...\n"
        echo -e "${message}"
        yad_error "${message}"
        exit 1
    fi
}

function delete_image() {   # Open imgbb at image to be deleted
    x-www-browser "${del_url}"
    switch_to_active
}

function delete_local(){    # delete local screenshot; don't delete if --file was script arg.
    local message ret
    source "${BL_YAD_INCLUDES}"
   
    if (( F_FLAG == 0));then    # local file wasn't uploaded, so don't offer to delete
        message="\n\tMove local screenshot image to 'Trash'?\n\n\t${img_file}\n"
        yad_common_args+=("--image=dialog-question")
        yad_question "${message}"
        ret="$?"
        yad_common_args+=("--image=0")
        if (( ret == 0 )); then
            if type "/usr/bin/gio" > /dev/null;then # 'gio' is part of 'gvfs' package
                gio trash "${img_file}"
            else
                rm "${img_file}"
            fi
        fi
    fi
}

function take_screenshot() {
    local cmd_scrot shot_err message
    
    cmd_scrot="${SCROT}$1"
    shot_err="$(${cmd_scrot} &>/dev/null)" #takes a screenshot
    if [ "$?" != "0" ]; then
        message="\n\tFailed to take screenshot of\n\t'$1':\n\n\tError: '${shot_err}'"
        echo -e "${message}"
        yad_error "${message}"
        exit 1
    fi
}

function show_image(){  # display image using viewer set in settings.conf
    # if image viewer not set, then default to browser
    [[ -z "${VIEWER}" ]] && VIEWER="x-www-browser"
    ${VIEWER} "$img_link"
    switch_to_active
}

function watermark_thumb() {    # add watermark to thumbnail if uploaded image has been deleted
    local input_img="${thumb_tempfile}"
    local delete_text="$HOME/tmp/deleted.png"

    # create watermark image
    convert  -background transparent -fill red -size 160x60 label:'UPLOAD\n     DELETED' "${delete_text}"
    # overlay thumbnail with watermark
    composite -dissolve 50% -gravity west "${delete_text}" "${thumb_tempfile}" "${thumb_tempfile}"
    
    rm "${delete_text}"
}
### END Image Functions ################################################

function get_client_api_key(){
    local message dlg ans dlg_msg dlg_err

    message='
        You need to Register or log in to your imgbb account to get an API Key.

        1.  Choose "Run browser" to go to "https://api.imgbb.com/"
        2.  Create account or Sign in, then return to the API page ("About">>"API").
        3.  "Get API key" and copy/paste it into the dialog entry field.
        4.  Choose "OK".
        
    '
    dlg=$(${DIALOG} --form --image=dialog-question --image-on-top \
    --title="imgbb Client API key" --text="${message}" \
    --fixed --center --borders=20 \
    --sticky --on-top \
    --width=650 \
    --field="Client API key:" "" \
    --button="Run browser":"/bin/bash -c 'run_browser addclient'" \
    ${OK} ${CANCEL}
    ) 2>/dev/null
    ans="$?"
    [[ ${ans} == 1 ]] && exit 0
    CLIENT_API_KEY="$(echo ${dlg} | awk -F '|' '{print $1}')" # 'pipe' separators

    # check returned values
    if [[ -z "${CLIENT_API_KEY}" ]] || (( ${#CLIENT_API_KEY} != 32 )) || ! [[ ${CLIENT_API_KEY} =~ ^[a-fA-F0-9]+$ ]];then
        err_msg="Client API key is wrong!"
    fi
    if [[ ${err_msg} ]]; then
        dlg_msg="\n${err_msg}\n\nTry again or Exit script?\n"
        dlg_err=$(${DIALOG} --text="${dlg_msg}" \
        --undecorated \
        --image="dialog-question" --button="Exit:1" ${OK}) 2>/dev/null
        ans=$?
        if (( ans == 0 )); then
            get_client_api_key
        else
            exit
        fi
    fi

    # write credentials to settings.conf
    # sed: change line containing <string> to <stringvar>
    api_line="CLIENT_API_KEY="\""${CLIENT_API_KEY}\""
    sed -i "s/^CLIENT_API_KEY.*/${api_line}/" "${SETTINGS_FILE}"
    source "${SETTINGS_FILE}"
}
function run_browser(){     # run browser with API url, and switch to attention-seeking browser tab
    local api_call="$1"     # function called from button in dialog
    if [[ ${api_call} = "addclient" ]]; then
        x-www-browser "${API_URL}" 2>/dev/null
    else
        x-www-browser "$1" 2>/dev/null
    fi
    switch_to_active
}

function switch_to_active(){   # switch to new browser tab
    local id
    for id in $(wmctrl -l | awk '{ print $1 }'); do
        # filter only windows demanding attention 
        xprop -id "$id" | grep -q "_NET_WM_STATE_DEMANDS_ATTENTION"
        if (( $? == 0 )); then
            wmctrl -i -a "$id"
#            exit 0
        fi
    done
}

function main(){
    settings_conf   # set up settings.conf if necessary

    # set defaults, if login not specified in script args
    SCROT="${SCREENSHOT_FULL_COMMAND}"        

    export -f run_browser   # to be used as YAD button command
    export -f switch_to_active # switch to active window
    export -f show_image        # to be used as YAD button command
    
    export VIEWER=$(grep -oP '(?<=VIEWER=").*(?=")' "${SETTINGS_FILE}")
    # for use by show_image()

    if ! . "${BL_YAD_INCLUDES}" 2> /dev/null; then
        echo "Error: Failed to source yad-includes in ${BL_YAD_INCLUDES}" >&2
        exit 1
    elif ! . "${SETTINGS_FILE}" 2> /dev/null; then
        echo "Error: Failed to source ${SETTINGS_FILE} in ${USR_CFG_DIR}/" >&2
        exit 1
    fi
    
    check_required  # check required programs are installed
    
    [[ -z "${CLIENT_API_KEY}" ]] && get_client_api_key
    getargs "${@}"
    getimage "${FNAME}"
     
    response="$(curl -s --location --request POST https://api.imgbb.com/1/upload?key=${CLIENT_API_KEY} \
    --form image=@${img_file})"

    del_url="$(jq -r '.data.delete_url' <<< "${response}")" && export del_url   # used by delete_image()
    img_link="$(jq -r '.data.image.url' <<< "${response}")" && export img_link  # used by show_image()
    img_small="$(jq -r '.data.thumb.url' <<< "${response}")"
    img_medium="$(jq -r '.data.medium.url' <<< "${response}")"

    bb_direct_link="[img]${img_link}[/img]"
    bb_thumb_linked="[url=${img_link}][img]${img_small}[/img][/url]"
    
    # download image thumbnail, for display in YAD dialog
    thumb_tempfile="${HOME}/tmp/thumb.jpg"
    wget -q -O "${thumb_tempfile}" "${img_small}"
    
    # Display BB Codes for uploaded image
    text='
        BB Code - Image thumbnail Linked

        Use Ctrl-C/Ctrl-V to copy/paste the selection

        '
    # Show 'Delete' button until image has been deleted
    while true;do
        if wget --spider "${del_url}" 2>/dev/null; then # page exists
            ret=$(${DIALOG} --image-on-top --image="${thumb_tempfile}" "${TITLE}" \
                --width=680 ${T}"${text}" --text-align=left \
                --form \
                --field='BB Code - Thumbnail linked':TXT "${bb_thumb_linked}" \
                --field='BB Code - Direct image link':TXT "${bb_direct_link}" \
                --button="Show Image":"/bin/bash -c 'show_image'" \
                ${DELETE} ${CLOSE} ) 2>/dev/null
            ret="$?"
            if (( ret == 2 )); then # block loop until image deletion is confirmed by user
                yad_common_args+=("--on-top" "--image=dialog-info")
                yad_info '
                    Click "Delete image" below the image  
                    on the imgbb page which will open.  
                    
                    Then choose  "Confirm"
                    
                    '
                yad_common_args+=("--on-top"=0 "--image=0")
                curr_desktop=$(xdotool get_desktop) # get Desktop index, so we can return to it
                delete_image
                dlg=$(${DIALOG} --on-top --undecorated \
                    ${T}"Choose 'OK' when you have deleted the image" \
                    ${OK} ${CANCEL} \
                    )
                ret=$?
                if (( $ret == 0 ));then
                    xdotool key ctrl+w  # close current tab, and resume loop
                    xdotool set_desktop ${curr_desktop}
                    watermark_thumb
                    continue
                else
                    xdotool key ctrl+w  # close current tab, and resume loop
                    xdotool set_desktop ${curr_desktop}
                    continue
                fi
            else        # dialog 'Close' chosen
                break
            fi
        else    # Image deletion confirmed, but user may still want to copy/paste BBCode
                # or view the image
            ret=$(${DIALOG} --image-on-top --image="${thumb_tempfile}" "${TITLE}" \
            --width=680 ${T}"${text}" --text-align=left \
            --form \
            --field='BB Code - Thumbnail linked':TXT "${bb_thumb_linked}" \
            --field='BB Code - Direct image link':TXT "${bb_direct_link}" \
            --button="Show Image":"/bin/bash -c 'show_image'" \
            ${CLOSE}  \
            ) 2>/dev/null
            break
        fi
        #break
    done
    delete_local
    rm "${thumb_tempfile}"
}
### END FUNCTIONS ######################################################

main "$@"
exit
