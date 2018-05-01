#!/bin/bash

function usage () {
        echo
        echo "Usage: ./UploadFile.sh -f \"File Name\" -s \"Syncpoint Name\" -l \"Folder Name\""
        echo
        echo
        echo "-f - First Name. If the name has spaces it must be inside double quotes."
        echo "-l - Last Name. If the name has spaces it must be inside double quotes."
        echo "-t - Type of account. Account types are:"
        echo
        echo "Examples:"
        echo "./UserAPIs.sh -o show-users"
        echo "./UserAPIs.sh -o create-user -u Username -f \"First Name\" -l \"Last Name\" -p Password -t Type -r Role"
        echo "./UserAPIs.sh -o edit-user -u Username -f \"First Name\" -l \"Last Name\" -p Password -r Role -e Email -d [0/1] -a [0/1]"
        exit 2


}

Folder=
while getopts "f:l:s:e:h" opt
do
        case ${opt} in
                f) File=$OPTARG ;;
                l) Folder=$OPTARG ;;
                s) Syncpoint=$OPTARG ;;
                e) Endpoint_Storage=$OPTARG ;;
                h) usage ;;
        esac
done
SyncpointID=$(./FileFolderMetadata.sh -o get-syncpoints | jq '.[] | "\(.Id) \(.Name)"' | tr -d '"' | grep -iw "$Syncpoint" | awk '{print $1}')
FileID=$(./FileFolderMetadata.sh -o get-files -s "$Syncpoint" -f "$Folder" | jq ".[] | select(.Filename==\"$File\")" | grep LatestVersionId | cut -d ':' -f2 | tr -d '", ')
V_TOKEN="$SyncpointID-$FileID"

if [[ -z $Endpoint_Storage ]] ; then
  Endpoint_Storage_ID=$(./FileFolderMetadata.sh -o get-default-storage | jq .Id | tr -d '" ')
else
  Endpoint_Storage_ID=$(./FileFolderMetadata.sh -o get-storage-endpoints | jq ".[] | select(.Name==\"$Endpoint_Storage\")" | jq .Id | tr -d '" ')
fi

if [[ -z $File ]] ; then echo "Please enter file!" && usage ; fi
if [[ -z $Syncpoint ]] ; then echo "Please enter file!" && usage ; fi

if [[ -z $Folder ]] ; then echo "Please enter folder!" && usage ; fi

appkey=$(grep 'App Key' /root/DemoAccount | cut -d : -f2 | tr -d ' ')
appsecret=$(grep 'App Secret' /root/DemoAccount | cut -d : -f2 | tr -d ' ')
usersyncapptoken=$(grep 'Application Token' /root/DemoAccount | cut -d : -f2 | tr -d ' ')
oauthbasic=$(echo -n "${appkey}:${appsecret}" | base64)

oauthresult=$(curl -sS -X POST https://api.syncplicity.com/oauth/token -H 'Authorization: Basic '${oauthbasic} -H "Sync-App-Token: ${usersyncapptoken}" -d 'grant_type=client_credentials')

accesstoken=$(echo ${oauthresult} | sed -e 's/[{}"]/''/g' | awk -v RS=',' -F: '/^access_token/ {print $2}')
companyID=$(echo ${oauthresult} | sed -e 's/[{}"]/''/g' | awk -v RS=',' -F: '/^user_company_id/ {print $2}')


#curl -sS -X POST -H "AppKey: ${appkey}" -H "Authorization: Bearer ${accesstoken}" -H "User-Agent: Avi-API" -H "Content-Range: 0-*/*" -F "sessionKey=Bearer ${accesstoken}"  -F "filename=$File" -F "fileData=@$File" -F "transfer-encoding=binary" -F "type=application/octet-stream" -F "sha256=$Hash" -F "virtualFolderId=$StorageID" -F "fileDone=" "https://data.syncplicity.com/saveFile.php?filepath=$File"

curl -o $File -sS -X GET -H "AppKey: ${appkey}" -H "Authorization: Bearer ${accesstoken}" "https://data.syncplicity.com/retrieveFile.php?vToken=$V_TOKEN"
echo
