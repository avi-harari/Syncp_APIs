#!/bin/bash

function usage () {
        echo
        echo "Usage: ./UploadFile.sh -f \"File Name\" -s \"Syncpoint Name\" -l \"Folder Name\""
        echo
        echo
        echo "-f - File Name. If the name has spaces it must be inside double quotes."
        echo "-s - Syncpoint Name. If the name has spaces it must be inside double quotes."
        echo "-l - Folder Name. If the name has spaces it must be inside double quotes."
        echo
        echo "Examples:"
        echo "./UploadFile.sh -f \"File Name\" -s \"Syncpoint Name\""
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

if [[ -z $File ]] ; then echo "Please enter file!" && usage ; fi
if [[ -z $Syncpoint ]] ; then echo "Please enter file!" && usage ; fi
StorageID=$(./FileFolderMetadata.sh -o get-syncpoints | jq '.[] | "\(.Id) \(.Name)"' | tr -d '"' | grep -iw "$Syncpoint" | awk '{print $1}')

if [[ ! -z $Folder ]] ; then
#Get path
#Figure out how to insert files with spaces in the filename
  Path=
fi

appkey=$(grep 'App Key' /root/DemoAccount | cut -d : -f2 | tr -d ' ')
appsecret=$(grep 'App Secret' /root/DemoAccount | cut -d : -f2 | tr -d ' ')
usersyncapptoken=$(grep 'Application Token' /root/DemoAccount | cut -d : -f2 | tr -d ' ')
oauthbasic=$(echo -n "${appkey}:${appsecret}" | base64)

oauthresult=$(curl -sS -X POST https://api.syncplicity.com/oauth/token -H 'Authorization: Basic '${oauthbasic} -H "Sync-App-Token: ${usersyncapptoken}" -d 'grant_type=client_credentials')

accesstoken=$(echo ${oauthresult} | sed -e 's/[{}"]/''/g' | awk -v RS=',' -F: '/^access_token/ {print $2}')
companyID=$(echo ${oauthresult} | sed -e 's/[{}"]/''/g' | awk -v RS=',' -F: '/^user_company_id/ {print $2}')

Hash=$(sha256sum $File | cut -d ' ' -f1)

curl -sS -X POST -H "AppKey: ${appkey}" -H "Authorization: Bearer ${accesstoken}" -H "User-Agent: Avi-API" -H "Content-Range: 0-*/*" -F "sessionKey=Bearer ${accesstoken}"  -F "filename=$File" -F "fileData=@$File" -F "transfer-encoding=binary" -F "type=application/octet-stream" -F "sha256=$Hash" -F "virtualFolderId=$StorageID" -F "fileDone=" "https://data.syncplicity.com/saveFile.php?filepath=$File"
echo
