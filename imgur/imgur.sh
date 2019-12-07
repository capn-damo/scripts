#!/usr/bin/env bash
#
# Take screenshots and upload them to Imgur.
# This can be to an existing account, or anonymously.
#
# Credentials and access token for an account can be set up.
#
# The script returns BB-Code for the direct image link, and a linked thumbnail.
# YAD dialogs are used for user interaction.
#
# imgur.sh by @damo December 2019
#
# Kudos to the writer of the script at https://github.com/jomo/imgur-screenshot,
# which has provided the OAuth2 and Imgur API functions used here.
# ("imgur-screenshot" is featured in https://imgur.com/tools.)
#
# Copyright (C) 2019 damo    <damo@bunsenlabs.org>
########################################################################

BL_COMMON_LIBDIR='/usr/lib/bunsen/common'
FILE_DIR="$(xdg-user-dir PICTURES)"
USR_CFG_DIR="$HOME/.config/imgur"
CREDENTIALS_FILE="${USR_CFG_DIR}/credentials.conf"
SETTINGS_FILE="${USR_CFG_DIR}/settings.conf"

SCRIPT=$(basename "$0")
read -d '' USAGE <<EOF
  imgur.sh [option]... [file]...

  With no script args, ${SCRIPT} will upload a screenshot of
  the full desktop, as anonymous user
  
  -h, --help                   Show this help, exit
  -c, --connect                Show connected Imgur account, exit
  -s, --select                 Take screenshot in select mode
  -w, --window                 Take screenshot in active window mode
  -f, --full                   Take screenshot in full desktop mode
  -l, --login                  Upload to Imgur account
  -a, --album <album_title>    Upload to specified album
  -t, --title <image title>    Label uploaded image
  -d, --delay <seconds>        Delay in integer seconds, before taking screenshot
  file  <filepath/filename>    Upload specified image. Overrides scrot options
  
  The final dialog displays forum BB-Code for both the direct image link and
  the linked image thumbnail. These can be copy/pasted as desired.

EOF

### Get script args ####################################################
function getargs(){
    if (( $# == 0 ));then               # no args, so run with anonymous, full desktop scrot
        echo -e "\nAnonymous upload\n"
        AUTH_MODE="A"
        SCROT="${SCREENSHOT_FULL_COMMAND}"
    fi
    while [ ${#} != 0 ]; do
        case "${1}" in
            -l | --login)   ID="${CLIENT_ID}" # run as auth user; username set in settings.conf
                            AUTH="Authorization: Bearer ${ACCESS_TOKEN}"  # in curl command
                            AUTH_MODE="L"
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
            -c | --connect) load_access_token
                            fetch_account_info
                            exit 0
                            ;;
            file)           FNAME="$2"
                            shift 
                            ;;
            -h | --help)    echo -e "${USAGE}"
                            exit 0
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
### File and Image functions #####################################################
function getimage(){
    if ! [[ -z ${DELAY} ]] && ! [[ ${SCROT} == "${SCREENSHOT_SELECT_COMMAND}" ]];then
        SCROT="${SCROT} -d ${DELAY} "
        MSG="\n\tNo image file provided...\n\tProceed with screenshot?\n \
        \n\tThere will be a pause of ${DELAY}s, to select windows etc\n"
    else
        MSG="\n\tNo image file provided...\n\tProceed with screenshot?\n"
    fi

    if [[ -z "${1}" ]]; then
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
    if [ ! -f "${IMG_FILE}" ]; then
        MSG="\n\tfile '${IMG_FILE}' doesn't exist!\n\n\tExiting script...\n"
        echo -e "${MSG}"
        yad_error "${MSG}"
        exit 1
    fi
}

function delete_image() {
    response="$(curl --compressed -X DELETE  -fsSL --stderr - -H "${AUTH}" \
    "https://api.imgur.com/3/image/$1")"
    yad_common_args+=("--image=dialog-info")
    
    if [ "${?}" -eq "0" ] && [ "$(jq -r .success <<< ${response})" = "true" ]; then
        MSG="\n\tImage successfully deleted (delete hash: $1).\n"
        yad_info "${MSG}"
        yad_common_args+=("--image=0")
    else
        MSG="\n\tThe image could not be deleted:\n\t${response}.\n"
        yad_error "${MSG}"
    fi
    echo -e "${MSG}"
}

function take_screenshot() {
    CMD_SCROT="${SCROT}$1"
    shot_err="$(${CMD_SCROT} &>/dev/null)" #takes a screenshot
    if [ "${?}" != "0" ]; then
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
  if [ -z "${CLIENT_ID}" ] || [ -z "${CLIENT_SECRET}" ]; then
    MSG='
        Your CLIENT_ID and CLIENT_SECRET are not set.
        Please register an imgur application at:
        
        https://api.imgur.com/oauth2/addclient

        Select "OAuth 2 authorization without a callback URL" and fill out the form.  
        Then, set the CLIENT_ID and CLIENT_SECRET in your settings.conf.        
    '
    yad_common_args+=("--image=dialog-info")
    yad_info "${MSG}"
    yad_common_args+=("--image=0")
    exit 1
  fi
}

function load_access_token() {
  local current_time preemptive_refresh_time expired

  TOKEN_EXPIRE_TIME=0
  # check for saved ACCESS_TOKEN and its expiration date
  if [ -f "${CREDENTIALS_FILE}" ]; then
    source "${CREDENTIALS_FILE}"
  fi
  if [ ! -z "${REFRESH_TOKEN}" ]; then    # token already set
    current_time="$(date +%s)"
    preemptive_refresh_time="600" # 10 minutes
    expired=$((current_time > (TOKEN_EXPIRE_TIME - preemptive_refresh_time)))
    if [ "${expired}" -eq "1" ]; then      # token expired
      refresh_access_token
    fi
  else
    acquire_access_token
    save_access_token
  fi
}

function acquire_access_token() {
    local url params param_name param_value
    read -d '' MSG <<EOF
You need to authorize ${SCRIPT} to upload images.
To grant access to this application visit the link below.

Then copy and paste the URL from your browser. 
It should look like "https://imgur.com/#access_token=..."

EOF
LINK="https://api.imgur.com/oauth2/authorize?client_id=${ID}&response_type=token"
        
    RET=$($DIALOG --form --image=dialog-info --image-on-top \
    --title="Get Imgur authorization" --text="${MSG}" \
    --fixed --center --borders=20 \
    --width=650 \
    --field="Copy link:" --field="Paste here: " "${LINK}" "" \
    )
    ANS="$?"
    [[ ${ANS} == 1 ]] && exit 0
    url="$(echo ${RET} | awk -F '|' '{print $2}')"

    if [[ ! "${url}" =~ "access_token=" ]]; then
        MSG="\n\tERROR: That URL doesn't look right, please start script again\n"
        yad_error "${MSG}"
        exit 1
    fi
    url="$(echo "${url}" | cut -d "#" -f 2-)"
    params=("${url//&/ }")
    
    for param in "${params[@]}"; do
        param_name="$(echo "${param}" | cut -d "=" -f 1)"
        param_value="$(echo "${param}" | cut -d "=" -f 2-)"
        case "${param_name}" in
            access_token)   ACCESS_TOKEN="${param_value}"
                            ;;
            refresh_token)  REFRESH_TOKEN="${param_value}"
                            ;;
            expires_in)     TOKEN_EXPIRE_TIME=$(( $(date +%s) + param_value ))
                            ;;
        esac
    done
    if [ -z "${ACCESS_TOKEN}" ] || [ -z "${REFRESH_TOKEN}" ] || [ -z "${TOKEN_EXPIRE_TIME}" ]; then
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
    local token_url response expires_in
    
    echo -e "\nRefreshing access token..."
    token_url="https://api.imgur.com/oauth2/token"
    # exchange the refresh token for ACCESS_TOKEN and REFRESH_TOKEN
    response="$(curl --compressed -fsSL --stderr - -F "client_id=${ID}" -F "client_secret=${CLIENT_SECRET}" -F "grant_type=refresh_token" -F "refresh_token=${REFRESH_TOKEN}" "${token_url}")"
    if [ ! "${?}" -eq "0" ]; then       # curl failed
        handle_upload_error "${response}" "${token_url}"
        exit 1
    fi
    
    if ! jq -re .access_token >/dev/null <<<"${response}"; then
        # server did not send access_token
        echo -e "\nError: Something is wrong with your credentials:"
        echo "${response}"
        exit 1
    fi
    
    ACCESS_TOKEN="$(jq -r .access_token <<<"${response}")"
    REFRESH_TOKEN="$(jq -r .refresh_token <<<"${response}")"
    expires_in="$(jq -r .expires_in <<<"${response}")"
    TOKEN_EXPIRE_TIME=$(( $(date +%s) + expires_in ))
    
    save_access_token
}

function fetch_account_info() {
    local response username
    
    response="$(curl -H "Authorization: Bearer ${ACCESS_TOKEN}" https://api.imgur.com/3/account/me)"
    if [ "${?}" -eq "0" ] && [ "$(jq -r .success <<<"${response}")" = "true" ]; then
        username="$(jq -r .data.url <<<"${response}")"
        MSG="\n\tLogged in as ${username}. \
        \n\n\thttps://${username,,}.imgur.com\n"
        echo -e "${MSG}"
        yad_info "${MSG}"
    else
        MSG="\n\tFailed to fetch info: ${response}\n"
        echo -e "${MSG}"        
        yad_info "${MSG}"
    fi
}

######## End OAuth Functions ###########################################

######## YAD ###########################################################
DIALOG="yad --center --borders=20 --window-icon=distributor-logo-bunsenlabs --fixed"
TITLE="--title=Image BBCode"
T="--text="
#COPY="--button=Copy:'xsel -b"
DELETE="--button=Delete:2"
CLOSE="--button=gtk-close:1"
TEXT="\tBB Code - Image thumbnail Linked \n
\tUse Ctrl-C/Ctrl-V to copy/paste the selection \n"
######## End YAD #######################################################

######## END FUNCTIONS #################################################

if ! . "${BL_COMMON_LIBDIR}/yad-includes" 2> /dev/null; then
    echo "Error: Failed to source yad-includes in ${BL_COMMON_LIBDIR}" >&2
    exit 1
elif ! . "${SETTINGS_FILE}" 2> /dev/null; then
    echo "Error: Failed to source ${SETTINGS_FILE} in ${USR_CFG_DIR}/" >&2
    exit 1
elif ! . "${CREDENTIALS_FILE}" 2> /dev/null; then
    echo "Error: Failed to source ${CREDENTIALS_FILE} in ${USR_CFG_DIR}/" >&2
    exit 1
fi

# set defaults, if login not specified in script args
ID="${ANON_ID}"
AUTH="Authorization: Client-ID ${ID}"           # in curl command
AUTH_MODE="A"
SCROT="${SCREENSHOT_FULL_COMMAND}"        

getargs "${@}"
getimage "${FNAME}"

if [[ "${AUTH_MODE}" = "L" ]];then        # logged in as user
    check_oauth2_client_secrets
    load_access_token
    if ! [[ -z "${ALBUM_TITLE}" ]];then   # upload to specified album
        ## get album id
        response=$(curl -H --location --request GET "https://api.imgur.com/3/account/${USER_NAME}/albums/ids" \
        --header "${AUTH}")
        declare -a ids 
        ids+=($(jq -r '.data[]' <<< "${response}"))
    
        # match album ids with chosen album title
        for (( i=0;i<=${#ids[@]};i++ ));do
            ID="${ids[$i]}"
            response=$(curl -H --location --request GET "https://api.imgur.com/3/account/${USER_NAME}/album/${ID}" --header "${AUTH}")
    
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