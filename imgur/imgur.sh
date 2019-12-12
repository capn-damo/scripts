#!/bin/bash
#
################### imgur.sh ###########################################
# Take screenshots and upload them to Imgur.
# This can be to an existing account, or anonymously.
#
# Credentials and access token for an account can be set up.
#
# Settings (settings.conf) and credentials (credentials.conf}) files are created in \
# $HOME/.config/imgur/
#
# The script returns BB-Code for the direct image link, and a linked thumbnail.
# YAD dialogs are used for user interaction.
#
# Kudos to the writer of the script at https://github.com/jomo/imgur-screenshot,
# which has provided most of the OAuth2 and Imgur API functions adapted here.
# ("imgur-screenshot" is featured in https://imgur.com/tools.)
#
# Copyright (C) 2019 damo    <damo@bunsenlabs.org>
########################################################################

BL_COMMON_LIBDIR='/usr/lib/bunsen/common'
USR_CFG_DIR="$HOME/.config/imgur"
CREDENTIALS_FILE="${USR_CFG_DIR}/credentials.conf"
SETTINGS_FILE="${USR_CFG_DIR}/settings.conf"
SCRIPT=$(basename "$0")

read -d '' USAGE <<EOF
  imgur.sh [option]... [file]...

  With no script args, ${SCRIPT} will upload a screenshot of
  the full desktop, as anonymous user
  
  -h, --help                   Show this help, exit
  -l, --login                  Upload to Imgur account
  -c, --connect                Show connected Imgur account, exit
  -s, --select                 Take screenshot in select mode
  -w, --window                 Take screenshot in active window mode
  -f, --full                   Take screenshot in full desktop mode
  -d, --delay <seconds>        Delay in integer seconds, before taking screenshot
  -a, --album <album_title>    Upload to specified album
  -t, --title <image title>    Label uploaded image
  file  <filepath/filename>    Upload specified image. Overrides scrot options
  
  The final dialog displays forum BB-Code for both the direct image link and
  the linked image thumbnail. These can be copy/pasted as desired.

  Options to delete uploaded and/or local screenshot images before exiting script.

EOF

### Get script args ####################################################
function getargs(){
    if (( $# == 0 ));then               # no args, so run with anonymous, full desktop scrot
        echo -e "\n\tAnonymous upload\n"
        AUTH_MODE="A"
        SCROT="${SCREENSHOT_FULL_COMMAND}"
    fi
    while [[ ${#} != 0 ]]; do
        case "$1" in
            -h | --help)    echo -e "${USAGE}"
                            exit 0
                            ;;
            -l | --login)   ID="${CLIENT_ID}" # run as auth user; username set in settings.conf
                            AUTH="Authorization: Bearer ${ACCESS_TOKEN}"  # in curl command
                            AUTH_MODE="L"
                            ;;
            -c | --connect) load_access_token
                            fetch_account_info
                            exit 0
                            ;;
            -s | --select)  SCROT="${SCREENSHOT_SELECT_COMMAND}"
                            ;;
            -w | --window)  SCROT="${SCREENSHOT_WINDOW_COMMAND}"
                            ;;
            -f | --full)    SCROT="${SCREENSHOT_FULL_COMMAND}"
                            ;;
            -d | --delay)   if [[ $2 != ?(-)+([0-9]) ]];then
                                MSG="\n\tDelay value must be an integer\n\tExiting script...\n"
                                echo -e "${MSG}"
                                yad_error "${MSG}"
                                exit 1
                            else
                                DELAY="$2"
                            fi
                            shift
                            ;;
            -a | --album)   ALBUM_TITLE="$2"    # override settings.conf
                            shift
                            ;;
            -t | --title)   IMG_TITLE="$2"
                            shift
                            ;;
            file)           FNAME="$2"
                            shift 
                            ;;
                         *) MSG="\n\tFailed to parse options\n\tExiting script...\n"
                            echo -e "${MSG}" >&2
                            yad_error "${MSG}"
                            exit 1
                            ;;
        esac || { echo "Failed to parse options" >&2 && exit 1; }
        shift
    done
}
### Initialize settings.conf config  ###################################
function settings_conf(){
    ! [[ -d "$USR_CFG_DIR" ]] && mkdir -p "$USR_CFG_DIR" 2>/dev/null

    if ! [[ -f "${SETTINGS_FILE}" ]] 2>/dev/null;then
        touch "${SETTINGS_FILE}" && chmod 600 "${SETTINGS_FILE}"
        cat <<EOF > "${SETTINGS_FILE}"
### IMGUR SCREENSHOT DEFAULT CONFIG ####
### Read by ${SCRIPT} ###################
# Most of these settings can be overridden with script args

# Imgur settings
ANON_ID="ea6c0ef2987808e"
CLIENT_ID=""
CLIENT_SECRET=""
USER_NAME=""
ALBUM_TITLE=""
IMGUR_ICON_PATH=""

# Local file settings
# User directory to save image:
FILE_DIR="$(xdg-user-dir PICTURES)"
FILE_NAME="imgur-%Y_%m_%d-%H:%M:%S"
# possible formats are png | jpg | tiff | gif
FILE_FORMAT="png"   

# Screenshot scrot commands
SCREENSHOT_SELECT_COMMAND="scrot -s "
SCREENSHOT_WINDOW_COMMAND="scrot -u -b "
SCREENSHOT_FULL_COMMAND="scrot "

EOF
    fi
source "${SETTINGS_FILE}"
}
### File and Image functions #####################################################
function getimage(){
    [[ ${AUTH_MODE} = "A" ]] && ANON="Anonymous "
    if ! [[ -z ${DELAY} ]] 2>/dev/null && ! [[ ${SCROT} == "${SCREENSHOT_SELECT_COMMAND}" ]] 2>/dev/null;then
        SCROT="${SCROT} -d ${DELAY} "
        MSG="\n\tNo image file provided...\n\tProceed with ${ANON}screenshot?\n \
        \n\tThere will be a pause of ${DELAY}s, to select windows etc\n"
    else
        SCROT="${SCROT} -d 1 "   # need a pause so YAD dialog can leave the scene
        MSG="\n\tNo image file provided...\n\tProceed with ${ANON}screenshot?\n"
    fi

    if [[ -z "$1" ]] 2>/dev/null; then
        yad_common_args+=("--image=dialog-question")
        yad_question "${MSG}"
        RET="$?"
        yad_common_args+=("--image=0")
       
        if (( RET == 1 ));then
            exit 0
        elif [[ ${SCROT} == "${SCREENSHOT_SELECT_COMMAND}" ]];then
            yad_info "\n\tDrag cursor to select area for screenshot\n"
        fi
        # new filename with date
        IMG_FILE="$(date +"${FILE_NAME}.${FILE_FORMAT}")"
        IMG_FILE="${FILE_DIR}/${IMG_FILE}"
        take_screenshot "${IMG_FILE}"
    else
        # upload file instead of screenshot
        IMG_FILE="$1"
    fi
    
    # check if file exists
    if ! [[ -f "${IMG_FILE}" ]] 2>/dev/null; then
        MSG="\n\tfile '${IMG_FILE}' doesn't exist!\n\n\tExiting script...\n"
        echo -e "${MSG}"
        yad_error "${MSG}"
        exit 1
    fi
}

function delete_image() {
    RESPONSE="$(curl --compressed -X DELETE  -fsSL --stderr - -H "${AUTH}" \
    "https://api.imgur.com/3/image/$1")"
    yad_common_args+=("--image=dialog-info")
    
    if (( $? == 0 )) && [[ $(jq -r .success <<< ${RESPONSE}) == "true" ]]; then
        MSG="\n\tUploaded image successfully deleted.\n\n\tdelete hash: $1\n"
        yad_info "${MSG}"
        yad_common_args+=("--image=0")
    else
        MSG="\n\tThe image could not be deleted:\n\t${RESPONSE}.\n"
        yad_error "${MSG}"
    fi
    echo -e "${MSG}"
    MSG="\n\tDelete local screenshot image?\n\n\t${IMG_FILE}\n"
    yad_common_args+=("--image=dialog-question")
    yad_question "${MSG}"
    RET="$?"
    yad_common_args+=("--image=0")
    (( RET == 1 )) && exit || rm "${IMG_FILE}"
}

function take_screenshot() {
    CMD_SCROT="${SCROT}$1"
    shot_err="$(${CMD_SCROT} &>/dev/null)" #takes a screenshot
    if [ "$?" != "0" ]; then
        MSG="\n\tFailed to take screenshot of\n\t'$1':\n\n\tError: '${shot_err}'"
        echo -e "${MSG}"
        yad_error "${MSG}"
        exit 1
    fi
}
####### END Image Functions ############################################

### OAuth Credentials Functions ########################################
### Adapted from https://github.com/jomo/imgur-screenshot ##############

function check_oauth2_client_secrets() {
#    if ! source "${SETTINGS_FILE}";then
    if [ -z "${CLIENT_ID}" ] || [ -z "${CLIENT_SECRET}" ]; then
        MSG='
            Your CLIENT_ID and CLIENT_SECRET are not set.
            
            You need to register an imgur application at:
            https://api.imgur.com/oauth2/addclient
        '
        DLG=$(${DIALOG} "${TITLE}" ${T}"${MSG}" --button="Get Credentials:0" ${CLOSE})
        RET=$?
        (( RET == 0 )) && get_oauth2_client_secrets || exit 1
    fi
#    fi
}

function get_oauth2_client_secrets(){
    #URL = "https://api.imgur.com/oauth2/addclient"
    MSG='
        Your CLIENT_ID and CLIENT_SECRET are not set.
        To register an imgur application:

        1: "Run browser"
        2: Select "OAuth 2 authorization without a callback URL" and fill out the form.
        3: Then, set the CLIENT_ID and CLIENT_SECRET in your settings.conf,
           or paste them in the fields below, and click "OK"
    '
    DLG=$($DIALOG --form --image=dialog-question --image-on-top \
    --title="Get Imgur authorization" --text="${MSG}" \
    --fixed --center --borders=20 \
    --sticky --on-top \
    --width=650 \
    --field="Client ID:" --field="Client Secret:" "" "" \
    --button="Run browser":"/bin/bash -c 'run_browser addclient'" \
    ${OK} ${CANCEL}
    )
    ANS="$?"
    [[ ${ANS} == 1 ]] && exit 0
    C_ID="$(echo ${DLG} | awk -F '|' '{print $1}')" # 'pipe' separators
    C_SECRET="$(echo ${DLG} | awk -F '|' '{print $2}')"
    
    # check returned values
    if [[ -z "${C_ID}" ]] || (( ${#C_ID} != 15 )) || ! [[ ${C_ID} =~ ^[a-fA-F0-9]+$ ]];then
        ERR_MSG_1="Client ID is wrong!"
    fi
    if [[ -z "${C_ID}" ]] || (( ${#C_SECRET} != 40 )) || ! [[ ${C_SECRET} =~ ^[a-fA-F0-9]+$ ]];then
        ERR_MSG_2="Client Secret is wrong!"
    fi
    if [[ ${ERR_MSG_1} ]] || [[ ${ERR_MSG_2} ]]; then
        DLG_MSG="\n${ERR_MSG_1}\n${ERR_MSG_2}\n\nTry again or Exit script?\n"
        ERR_DLG=$(${DIALOG} --text="${DLG_MSG}" --undecorated \
        --image="dialog-question" --button="Exit:1" ${OK})
        ANS=$?
        if (( ${ANS} == 0 )); then
            get_oauth2_client_secrets
        else
            exit
        fi
    fi

    # write credentials to settings.conf
    # sed: change line containing <string> to <stringvar>
    C_ID_LINE="CLIENT_ID="\""${C_ID}\""
    C_SECRET_LINE="CLIENT_SECRET="\""${C_SECRET}\""
    sed -i "s/^CLIENT_ID.*/${C_ID_LINE}/" "${SETTINGS_FILE}"
    sed -i "s/^CLIENT_SECRET.*/${C_SECRET_LINE}/" "${SETTINGS_FILE}"
    source "${SETTINGS_FILE}"
}

function load_access_token() {
    local CURRENT_TIME PREEMPTIVE_REFRESH_TIME EXPIRED
    TOKEN_EXPIRE_TIME=0
    ID="$1"     # CLIENT_ID

    if [[ ${ID} == "${ANON_ID}" ]];then # user has used '-l' or '-c' args, without credentials
        MSG="\n\tSorry, you need to Register an Imgur account\n\tbefore being able to log in!\n"
        echo -e "${MSG}"
        yad_error "${MSG}" #&& exit
        get_oauth2_client_secrets
    else
        AUTH_MODE="L"
    fi 
    # check for saved ACCESS_TOKEN and its expiration date
    if [[ -f "${CREDENTIALS_FILE}" ]] 2>/dev/null; then
        source "${CREDENTIALS_FILE}"
    else
        acquire_access_token
        save_access_token
    fi
    if [[ ! -z "${REFRESH_TOKEN}" ]] 2>/dev/null; then    # token already set
        CURRENT_TIME="$(date +%s)"
        PREEMPTIVE_REFRESH_TIME="600" # 10 minutes
        EXPIRED=$((CURRENT_TIME > (TOKEN_EXPIRE_TIME - PREEMPTIVE_REFRESH_TIME)))
        if [[ ${expired} == "1" ]]; then      # token expired
            refresh_access_token
        fi
    else
        acquire_access_token
        save_access_token
    fi
}

function acquire_access_token() {
    local URL PARAMS PARAM_NAME PARAM_VALUE MSG
    read -d '' MSG <<EOF
You need to authorize ${SCRIPT} to upload images.

To grant access to this application visit the link below, by clicking "Run browser".

"https://api.imgur.com/oauth2/authorize?client_id=${ID}&amp;response_type=token"

Then copy and paste the URL from your browser. 
It should look like "https://imgur.com/#access_token=..."

EOF

    # need to expand variable in dialog
    CMD="$(printf '/bin/bash -c "run_browser token %s"' "${ID}")"
    
    RET=$($DIALOG --form --image=dialog-info --image-on-top \
    --title="Get Imgur authorization" --text="${MSG}" \
    --fixed --sticky --on-top --center --borders=20 \
    --width=650  \
    --field="Paste here: " "" \
    --button="Run browser":"${CMD}" \
    --button="Save token:0" ${CANCEL}
    )
    ANS="$?"
    [[ ${ANS} == 1 ]] && exit 0
    URL="${RET:0:-1}"   # cut 'pipe' char from end of string
    if ! [[ ${URL} =~ "access_token=" ]] 2>/dev/null; then
        MSG="\n\tERROR: That URL doesn't look right, please start script again\n"
        yad_error "${MSG}"
        exit 1
    fi
    URL="$(echo "${URL}" | cut -d "#" -f 2-)"   # remove leading 'https://imgur.com/#'
    PARAMS=(${URL//&/ })                        # add remaining sections to array
    
    for param in "${PARAMS[@]}"; do
        PARAM_NAME="$(echo "${param}" | cut -d "=" -f 1)"
        PARAM_VALUE="$(echo "${param}" | cut -d "=" -f 2-)"
        
        case "${PARAM_NAME}" in
            access_token)   ACCESS_TOKEN="${PARAM_VALUE}"
                            ;;
            refresh_token)  REFRESH_TOKEN="${PARAM_VALUE}"
                            ;;
            expires_in)     TOKEN_EXPIRE_TIME=$(( $(date +%s) + PARAM_VALUE ))
                            ;;
        esac
    done
    if [[ -z "${ACCESS_TOKEN}" ]] || [[ -z "${REFRESH_TOKEN}" ]] || [[ -z "${TOKEN_EXPIRE_TIME}" ]]; then
        MSG="\n\tERROR: Failed parsing the URL.\n\n\tDid you copy the full URL?\n"
        yad_error "${MSG}"
        exit 1
    fi
    save_access_token
}

function save_access_token() {
    # create dir if not exist
    mkdir -p "$(dirname "${CREDENTIALS_FILE}")" 2>/dev/null
    touch "${CREDENTIALS_FILE}" && chmod 600 "${CREDENTIALS_FILE}"
    cat <<EOF > "${CREDENTIALS_FILE}"
# This file is generated by ${SCRIPT}
# Do not modify it here - it will be overwritten
ACCESS_TOKEN="${ACCESS_TOKEN}"
REFRESH_TOKEN="${REFRESH_TOKEN}"
TOKEN_EXPIRE_TIME="${TOKEN_EXPIRE_TIME}"
EOF
}

function refresh_access_token() {
    local TOKEN_URL RESPONSE EXPIRES_IN
    
    echo -e "\nRefreshing access token..."
    TOKEN_URL="https://api.imgur.com/oauth2/token"
    # exchange the refresh token for ACCESS_TOKEN and REFRESH_TOKEN
    RESPONSE="$(curl --compressed -fsSL --stderr - -F "client_id=${ID}" -F "client_secret=${CLIENT_SECRET}" -F "grant_type=refresh_token" -F "refresh_token=${REFRESH_TOKEN}" "${TOKEN_URL}")"
    if [ ! "${?}" -eq "0" ]; then       # curl failed
        handle_upload_error "${RESPONSE}" "${TOKEN_URL}"
        exit 1
    fi
    
    if ! jq -re .access_token >/dev/null <<<"${RESPONSE}"; then
        # server did not send access_token
        echo -e "\nError: Something is wrong with your credentials:"
        echo "${RESPONSE}"
        exit 1
    fi
    
    ACCESS_TOKEN="$(jq -r .access_token <<<"${RESPONSE}")"
    REFRESH_TOKEN="$(jq -r .refresh_token <<<"${RESPONSE}")"
    EXPIRES_IN="$(jq -r .expires_in <<<"${RESPONSE}")"
    TOKEN_EXPIRE_TIME=$(( $(date +%s) + EXPIRES_IN ))
    save_access_token
}

function fetch_account_info() {
    local RESPONSE USERNAME
    
    RESPONSE="$(curl -sH "Authorization: Bearer ${ACCESS_TOKEN}" https://api.imgur.com/3/account/me)"
    if (( $? == 0 )) && [[ $(jq -r .success <<<"${RESPONSE}") = "true" ]]; then
        USERNAME="$(jq -r .data.url <<<"${RESPONSE}")"
        MSG="\n\tLogged in as ${USERNAME}. \
        \n\n\thttps://${USERNAME,,}.imgur.com\n"
        echo -e "${MSG}"
        yad_common_args+=("--image=dialog-info")
        yad_info "${MSG}"
        yad_common_args+=("--image=0")
    else
        MSG="\n\tFailed to fetch info: ${RESPONSE}\n"
        echo -e "${MSG}"
        yad_common_args+=("--image=dialog-info")
        yad_info "${MSG}"
        yad_common_args+=("--image=0")
    fi
}

function run_browser(){     # run browser with API url, and switch to attention-seeking browser tab
    local API_CALL="$1"     # function called from button in dialog
    ID_ARG="$2"
    [[ ${API_CALL} = "addclient" ]] && API_URL="https://api.imgur.com/oauth2/addclient"
    [[ ${API_CALL} = "token" ]] && API_URL="https://api.imgur.com/oauth2/authorize?client_id=${ID_ARG}&response_type=token"
    x-www-browser "${API_URL}" 2>/dev/null
    switch_to_browser
}

function switch_to_browser(){   # switch to new browser tab
    for id in $(wmctrl -l | awk '{ print $1 }'); do
        # filter only windows demanding attention 
        xprop -id $id | grep -q "_NET_WM_STATE_DEMANDS_ATTENTION"
        if (( $? == 0 )); then
            wmctrl -i -a $id
            exit 0
        fi
    done
}

######## End OAuth Functions ###########################################

######## YAD ###########################################################
DIALOG="yad --center --borders=20 --window-icon=distributor-logo-bunsenlabs --fixed"
TITLE="--title=Image BBCode"
T="--text="
DELETE="--button=Delete:2"
CLOSE="--button=gtk-close:1"
CANCEL="--button=gtk-cancel:1"
OK="--button=OK:0"
######## End YAD #######################################################
######## END FUNCTIONS #################################################

### main ###############################################################

settings_conf   # set up settings.conf if necessary

# set defaults, if login not specified in script args
ID="${ANON_ID}"
AUTH="Authorization: Client-ID ${ID}"           # in curl command
AUTH_MODE="A"
SCROT="${SCREENSHOT_FULL_COMMAND}"        

export -f run_browser   # to be used as YAD button command
export -f switch_to_browser # used by run_browser

if ! . "${BL_COMMON_LIBDIR}/yad-includes" 2> /dev/null; then
    echo "Error: Failed to source yad-includes in ${BL_COMMON_LIBDIR}" >&2
    exit 1
elif ! . "${SETTINGS_FILE}" 2> /dev/null; then
    echo "Error: Failed to source ${SETTINGS_FILE} in ${USR_CFG_DIR}/" >&2
    exit 1
elif ! . "${CREDENTIALS_FILE}" 2> /dev/null; then
    echo "Error: Failed to source ${CREDENTIALS_FILE} in ${USR_CFG_DIR}/" >&2
    if ! [[ -z "${CLIENT_ID}" ]];then
        load_access_token "${CLIENT_ID}"
    else
        load_access_token "${ANON_ID}"
    fi
fi

getargs "${@}"
getimage "${FNAME}"

if [[ "${AUTH_MODE}" = "L" ]];then        # logged in as user
    check_oauth2_client_secrets
    load_access_token
    if ! [[ -z "${ALBUM_TITLE}" ]];then   # upload to specified album
        ## get album id
        response=$(curl -sH --location --request GET "https://api.imgur.com/3/account/${USER_NAME}/albums/ids" \
        --header "${AUTH}")
        declare -a ids 
        ids+=($(jq -r '.data[]' <<< "${response}"))
    
        # match album ids with chosen album title
        for (( i=0;i<=${#ids[@]};i++ ));do
            ID="${ids[$i]}"
            response=$(curl -sH --location --request GET "https://api.imgur.com/3/account/${USER_NAME}/album/${ID}" --header "${AUTH}")
    
            title="$(jq -r '.data.title' <<< "${response}")"
            if [[ "${title}" = "${ALBUM_TITLE}" ]];then
                ALBUM_ID="${ids[$i]}"
            else
                continue
            fi
        done
        response="$(curl  -sH "${AUTH}" -F "image=@\"${IMG_FILE}\"" -F "title=${IMG_TITLE}" -F "album=${ALBUM_ID}" https://api.imgur.com/3/image)"
    else    # don't upload to an album
        response="$(curl  -sH "${AUTH}" -F "image=@\"${IMG_FILE}\"" -F "title=${IMG_TITLE}" https://api.imgur.com/3/image)"
    fi
else    # anonymous upload
    response="$(curl -sH "${AUTH}" -F "image=@\"${IMG_FILE}\"" -F "title=${IMG_TITLE}" https://api.imgur.com/3/image)"
fi
DEL_HASH="$(jq -r '.data | .deletehash' <<< "${response}")"
IMG_LINK="$(jq -r '.data.link' <<< "${response}")"
IMG_F="${IMG_LINK%.*}"
IMG_EXT="${IMG_LINK##*.}"
IMG_THUMB="${IMG_F}t.${IMG_EXT}"

BB_DIRECT="[img]${IMG_LINK}[/img]"
BB_THUMB_LINKED="[url=${IMG_LINK}][img]${IMG_THUMB}[/img][/url]"

# download image thumbnail, for display in YAD dialog
TEMP_THUMB="${HOME}/tmp/thumb.jpg"
wget -q -O "${TEMP_THUMB}" "${IMG_THUMB}"

# Display BB Codes for uploaded image
TEXT="\tBB Code - Image thumbnail Linked \n
\tUse Ctrl-C/Ctrl-V to copy/paste the selection \n"

RET=$(${DIALOG} --image-on-top --image="${TEMP_THUMB}" "${TITLE}" \
    --form \
    --field='BB Code - Thumbnail linked':TXT "${BB_THUMB_LINKED}" \
    --field='BB Code - Direct image link':TXT "${BB_DIRECT}" \
    ${DELETE} ${CLOSE}  --width=680 ${T}"${TEXT}" --text-align=left)

RET="$?"
if (( RET == 2 ));then
    delete_image "${DEL_HASH}"
fi

rm "${TEMP_THUMB}"

exit
