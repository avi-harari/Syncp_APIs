#!/bin/bash

function usage () {
        echo
        echo "Usage: ./DownloadFile.sh -f \"File Name\" -s \"Syncpoint Name\" -l \"Folder Name\""
        echo
        echo
        echo "-f - File Name. If the name has spaces it must be inside double quotes."
        echo "-l - Folder Name. If the name has spaces it must be inside double quotes."
        echo "-s - Syncpoint Name. If the name has spaces it must be inside double quotes."
        echo
        echo "Examples:"
        echo "./DownloadFile.sh -f \"File Name\" -s \"Syncpoint Name\""
        echo "./DownloadFile.sh -f \"File Name\" -s \"Syncpoint Name\" -l \"Folder Name\""
        exit 2


}

Folder=
while getopts "f:l:s:h" opt
do
        case ${opt} in
                f) File=$OPTARG ;;
                l) Folder=$OPTARG ;;
                s) Syncpoint=$OPTARG ;;
                h) usage ;;
        esac
done

SyncpointID=$(./FileFolderMetadata.sh -o get-syncpoints | jq '.[] | "\(.Id) \(.Name)"' | tr -d '"' | grep -iw "$Syncpoint" | awk '{print $1}')
FileID=$(./FileFolderMetadata.sh -o get-files -s "$Syncpoint" -f "$Folder" | jq ".[] | select(.Filename==\"$File\")" | grep LatestVersionId | cut -d ':' -f2 | tr -d '", ')
V_TOKEN="$SyncpointID-$FileID"

if [[ -z $File ]] ; then echo "Please enter file!" && usage ; fi
if [[ -z $Syncpoint ]] ; then echo "Please enter file!" && usage ; fi

if [[ -z $Folder ]] ; then echo "Please enter folder!" && usage ; fi

appkey=$(grep 'App Key' /root/DemoAccount | cut -d : -f2 | tr -d ' ')
appsecret=$(grep 'App Secret' /root/DemoAccount | cut -d : -f2 | tr -d ' ')
usersyncapptoken=$(grep 'Application Token' /root/DemoAccount | cut -d : -f2 | tr -d ' ')
oauthbasic=$(echo -n "${appkey}:${appsecret}" | base64)

oauthresult=$(curl -sS -X POST https://api.syncplicity.com/oauth/token -H 'Authorization: Basic '${oauthbasic} -H "Sync-App-Token: ${usersyncapptoken}" -d 'grant_type=client_credentials')

accesstoken=$(echo ${oauthresult} | sed -e 's/[{}"]/''/g' | awk -v RS=',' -F: '/^access_token/ {print $2}')


curl -o $File -sS -X GET -H "AppKey: ${appkey}" -H "Authorization: Bearer ${accesstoken}" "https://data.syncplicity.com/retrieveFile.php?vToken=$V_TOKEN"
echo
