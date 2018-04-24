#!/bin/bash

function usage () {
        echo
        echo "Usage: ./FileFolderMetadata.sh -o [Option] -f [\"Folder Name\"] -s [\"Syncpoint Name\"]"
        echo
        echo "Options:"
        echo "-o - options are:"
        echo
        echo "get-syncpoints - Get all syncpoints."
        echo "get-folders - Get all folders from syncpoint."
        echo "get-sub-folders - Get all sub-folders from folder."
        echo "get-files - Get files from folder. Requires syncpoint and folder."
        echo "delete-folder - Delete folder. Requires syncpoint and folder."
        echo "create-folder - Create folder. Requires syncpoint, folder and new folder name."
        echo
        echo "-f - Folder name. If folder name has spaces it must be inside double quotes."
        echo "-s - Syncpoint name. If syncpoint name has spaces it must be inside double quotes."
        echo "-n - New folder name. If folder name has spaces it must be inside double quotes. Only used with create-folder option."
        echo
        echo "Examples:"
        echo "./FileFolderMetadata.sh -o get-syncpoints"
        echo "./FileFolderMetadata.sh -o get-files -s \"Syncpoint Name\" -f \"Folder Name\""
        exit 2


}

while getopts "o:u:f:s:n:e:v:h" opt
do
        case ${opt} in
                o) OPTION=$OPTARG ;;
                u) USER=$OPTARG ;;
                f) FolderName=$OPTARG ;;
                s) Syncpoint=$OPTARG ;;
                n) NewFolderName=$OPTARG ;;
                e) ExistingFilename=$OPTARG ;;
                v) VirtualPath=$OPTARG ;;
                h) usage ;;
        esac
done

appkey=$(grep 'App Key' DemoAccount | cut -d : -f2 | tr -d ' ')
appsecret=$(grep 'App Secret' DemoAccount | cut -d : -f2 | tr -d ' ')
usersyncapptoken=$(grep 'Application Token' DemoAccount | cut -d : -f2 | tr -d ' ')
oauthbasic=$(echo -n "${appkey}:${appsecret}" | base64)

oauthresult=$(curl -sS -X POST https://api.syncplicity.com/oauth/token -H 'Authorization: Basic '${oauthbasic} -H "Sync-App-Token: ${usersyncapptoken}" -d 'grant_type=client_credentials')
accesstoken=$(echo ${oauthresult} | sed -e 's/[{}"]/''/g' | awk -v RS=',' -F: '/^access_token/ {print $2}')
companyID=$(echo ${oauthresult} | sed -e 's/[{}"]/''/g' | awk -v RS=',' -F: '/^user_company_id/ {print $2}')

RED='\033[0;31m'
GREEN='\033[0;32m'
PURPLE='\033[0;35m'
YELLOW='\033[1;33m'
NC='\033[0m'

#Get All Syncpoints
GetAllSyncpoints ()
{
  curl -sS -X GET --header "Accept: application/json" -H "AppKey: ${appkey}" -H "Authorization: Bearer ${accesstoken}" --header "As-User: " "https://api.syncplicity.com/syncpoint/syncpoints.svc/" | python -m json.tool
}

#Get Syncpoint ID
GetSyncpointID ()
{
  if [[ -z $Syncpoint ]] ; then echo "Syncpoint name is missing" && usage ; fi
  GetAllSyncpoints | jq '.[] | "\(.Id) \(.Name)"' | tr -d '"' | grep -iw "$Syncpoint" | awk '{print $1}'
}

GetRootFolderID ()
{
  if [[ -z $Syncpoint ]] ; then echo "Syncpoint name is missing" && usage ; fi
  GetAllSyncpoints | jq '.[] | "\(.RootFolderId) \(.Name)"' | tr -d '"' | grep -iw "$Syncpoint" | awk '{print $1}'
}

#Get Folders From Syncpoint
GetFoldersFromSyncpoint ()
{
  curl -sS -X GET --header "Accept: application/json" -H "AppKey: ${appkey}" -H "Authorization: Bearer ${accesstoken}" "https://api.syncplicity.com/sync/folders.svc/$(GetSyncpointID)/folders" | python -m json.tool
}

#Get Folder ID
GetFolderID ()
{
  if [[ -z $FolderName ]] ; then echo "Folder name is missing" && usage ; fi
  GetFoldersFromSyncpoint | jq '.[] |"\(.FolderId) \(.Name)"' | tr -d '",' | grep -iw "$FolderName" | awk '{print $1}'
}

GetFilesFromFolder ()
{
  curl -sS -X GET --header "Accept: application/json" -H "AppKey: ${appkey}" -H "Authorization: Bearer ${accesstoken}" --header "As-User: " "https://api.syncplicity.com/sync/folder_files.svc/$(GetSyncpointID)/folder/$FolderID/files" | python -m json.tool
}

GetSubFoldersFromFolder ()
{
  curl -sS -X GET --header "Accept: application/json" -H "AppKey: ${appkey}" -H "Authorization: Bearer ${accesstoken}" --header "As-User: " "https://api.syncplicity.com/sync/folder_folders.svc/$(GetSyncpointID)/folder/$FolderID/folders" | python -m json.tool
}

DeleteFolder ()
{
  if [[ $FolderName = "/" ]] ; then echo "Cannot delete since this is a syncpoint" && exit 1 ; fi
  curl -X DELETE --header "Accept: application/json" -H "AppKey: ${appkey}" -H "Authorization: Bearer ${accesstoken}" --header "As-User: " "https://api.syncplicity.com/sync/folder.svc/$(GetSyncpointID)/folder/$(GetFolderID)"
}

CreateFolder ()
{
  curl -X POST --header "Accept: application/json" -H "AppKey: ${appkey}" -H "Authorization: Bearer ${accesstoken}" --header "As-User: " --header "Content-Type: application/json" -d "[ {\"Name\": \"$NewFolderName\",\"Status\": 1} ]" "https://api.syncplicity.com/sync/folder_folders.svc/$(GetSyncpointID)/folder/$FolderID/folders" | python -m json.tool
}

CreateFolderSP ()
{
  SYNCPOINT_ID=$(GetSyncpointID)
  VirtualPath="$(GetFoldersFromSyncpoint | jq ".[] | select(.Name==\"$FolderName\")" | grep VirtualPath | cut -d ':' -f2 | tr -d '", ')$NewFolderName$(echo -n '\\')"
  curl -v -sS -X POST --header "Content-Type: " --header "Accept: application/json" -H "AppKey: ${appkey}" -H "Authorization: Bearer ${accesstoken}" -d "[ {\"SyncpointId\": \"$SYNCPOINT_ID\", \"Name\": \"$NewFolderName\", \"Status\": 1, \"VirtualPath\": \"$VirtualPath\"} ]" "https://api.syncplicity.com/sync/folders.svc/$SYNCPOINT_ID/folders" | python -m json.tool
}

GetDefaultStorage ()
{
  curl -sS -X GET --header "Accept: application/json" -H "AppKey: ${appkey}" -H "Authorization: Bearer ${accesstoken}" --header "As-User: " "https://api.syncplicity.com/storage/storageendpoint.svc/" | python -m json.tool

}

GetFileVersions ()
{
  FILE_VERSION_ID=$(GetFilesFromFolder | jq ".[] | select(.Filename==\"$ExistingFilename\")" | grep LatestVersionId | cut -d ':' -f2 | tr -d '", ')
  curl -sS -X GET --header "Accept: application/json" -H "AppKey: ${appkey}" -H "Authorization: Bearer ${accesstoken}" --header "As-User: " "https://api.syncplicity.com/sync/versions.svc/$(GetSyncpointID)/file/$FILE_VERSION_ID/versions" | python -m json.tool
}

if [[ $FolderName = "/" ]] ; then FolderID=$(GetRootFolderID) ; else FolderID=$(GetFolderID) ; fi

if [[ $OPTION = 'get-syncpoints' ]]; then
  GetAllSyncpoints
elif [[ $OPTION = 'get-folders' ]]; then
  GetFoldersFromSyncpoint
elif [[ $OPTION = 'get-sub-folders' ]]; then
  GetSubFoldersFromFolder
elif [[ $OPTION = 'get-files' ]]; then
  GetFilesFromFolder
elif [[ $OPTION = 'delete-folder' ]]; then
  DeleteFolder
elif [[ $OPTION = 'create-folder' ]]; then
  CreateFolder
elif [[ $OPTION = 'create-folder-sp' ]]; then
  CreateFolderSP
elif [[ $OPTION = 'get-default-storage' ]]; then
  GetDefaultStorage
elif [[ $OPTION = 'get-file-versions' ]]; then
  GetFileVersions
else
  usage
fi