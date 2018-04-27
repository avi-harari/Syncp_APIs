#!/bin/bash

function usage () {
        echo
        echo "Usage: ./UserAPIs.sh -o [Option] -u Username -g \"Group Name\" -s \"Syncpoint Name\" -f \"File Name\" -l \"Folder Name\" -w [0/1] -p Password -e [0/1] -t Time(numeric value) -d [1/2/3/4] -m [1/2/3/4] "
        echo
        echo "Options:"
        echo "-o - options are:"
        echo
        echo "get-all-links - Show all links."
        echo "create-link - Create new link."
        echo "delete-link - Delete user."
        echo "get-link - Show link details."
        echo "edit-link - Edit single link."
        echo
        echo "-u - Username (email)."
        echo "-g - Group Name. If the name has spaces it must be inside double quotes."
        echo "-s - Syncpoint Name. If the name has spaces it must be inside double quotes."
        echo "-f - File name. If the name has spaces it must be inside double quotes."
        echo "-l - Folder name. If the name has spaces it must be inside double quotes."
        echo "-w - With password. Enable password protection. 1 is disabled, 2 is enabled. Default is 1."
        echo "-p - Password for the link."
        echo "-e - Expiration enabled. 0 to disable expiration, 1 to enable. Default is 1."
        echo "-t - Time period for expiration."
        echo "-d - Shared link policy. 1 for disabled, 2 for internal domain only, 3 for allow all and 4 for intended only(user or group). Default value is 3."
        echo "-m - Outlook sharing policy. 1 for disabled, 2 for internal domain only, 3 for allow all and 4 for intended only(user or group). Default value is 3."
        echo
        echo "Examples:"
        echo "./LinksAPIs.sh -o get-all-links"
        echo "./LinksAPIs.sh -o create-link -f \"File Name\" -l \"Folder Name\" -s \"Syncpoint Name \""
        echo "./LinksAPIs.sh -o edit-link -u Username/-g Group -f \"File Name\" -l \"Folder Name\" -s \"Syncpoint Name \""
        echo
        exit 2


}

Disable=3
Mail=3
WithPass=1
Expiration=1
Time=60
USER=

while getopts "o:u:g:s:f:l:p:e:t:d:m:h" opt
do
        case ${opt} in
                o) OPTION=$OPTARG ;;
                u) USER=$OPTARG ;;
                g) Group=$OPTARG ;;
                s) Syncpoint=$OPTARG ;;
                f) File=$OPTARG ;;
                l) Folder=$OPTARG ;;
                p) Password=$OPTARG ;;
                e) Expiration=$OPTARG ;;
                t) Time=$OPTARG ;;
                w) WithPass=$OPTARG ;;
                d) Disable=$OPTARG ;;
                m) Mail=$OPTARG ;;
                h) usage ;;
        esac
done

appkey=$(grep 'App Key' /root/DemoAccount | cut -d : -f2 | tr -d ' ')
appsecret=$(grep 'App Secret' /root/DemoAccount | cut -d : -f2 | tr -d ' ')
usersyncapptoken=$(grep 'Application Token' /root/DemoAccount | cut -d : -f2 | tr -d ' ')
oauthbasic=$(echo -n "${appkey}:${appsecret}" | base64)

oauthresult=$(curl -sS -X POST https://api.syncplicity.com/oauth/token -H 'Authorization: Basic '${oauthbasic} -H "Sync-App-Token: ${usersyncapptoken}" -d 'grant_type=client_credentials')

accesstoken=$(echo ${oauthresult} | sed -e 's/[{}"]/''/g' | awk -v RS=',' -F: '/^access_token/ {print $2}')
companyID=$(echo ${oauthresult} | sed -e 's/[{}"]/''/g' | awk -v RS=',' -F: '/^user_company_id/ {print $2}')


GetAllLinks ()
{
  curl -sS -X GET --header "Accept: application/json" -H "AppKey: ${appkey}" -H "Authorization: Bearer ${accesstoken}" --header "As-User: " "https://api.syncplicity.com/syncpoint/links.svc/" | python -m json.tool
}

GetSyncpointID ()
{
  ./FileFolderMetadata.sh -o get-syncpoints -s $Syncpoint | jq '.[] | "\(.Id) \(.Name)"' | tr -d '"' | grep -iw "$Syncpoint" | awk '{print $1}' 
}

GetGroupID ()
{
  ./GroupAPIs.sh -o get-all-groups | jq ".[] | select(.Name==\"$Group\")" | jq .Id | tr -d '" '
}

GetVirtualPath ()
{
  ./FileFolderMetadata.sh -o get-folders -s "$Syncpoint" | jq ".[] | select(.Name==\"$Folder\")" | grep -iw "VirtualPath" | cut -d ':' -f2 | tr -d '", '
}

UserOrGroup ()
{
  if [ $Disable = 4 ] ; then
    if [[ ! -z $USER ]] && [[ -z $Group ]] ; then
      echo -n '"Users": [ {"EmailAddress": "'$USER'"} ], '
    elif [[ ! -z $Group ]] && [[ -z $USER ]] ; then
      echo -n '"Groups": [ {"Id": "'$(GetGroupID)'"} ], '
    fi
  fi
}

GetUserID ()
{
  ./UserAPIs.sh -o show-user -u $USER | jq .Id | tr -d '" '
}

JQUserOrGroup ()
{
  if [[ -z $USER ]] && [[ ! -z $Group ]] ; then
    echo -n '(.Groups[].Name=="'$Group'")'
  elif [[ -z $Group ]] && [[ ! -z $USER ]] ; then
    echo -n '(.Users[].Id=="'$(GetUserID)'")'
  fi
}

VerifyUserOrGroup ()
{
  if [[ ! -z $Group ]] && [[ ! -z $USER ]] ; then
    echo "Cannot use both user and group, enter only one of the two!" && usage
  elif [[ -z $Group ]] && [[ -z $USER ]] ; then
    echo "No user or group entered!" && usage
  fi
}

GetToken ()
{
  VerifyUserOrGroup
  GetAllLinks | jq ".[] | select((.File.Filename==\"$File\") and $(JQUserOrGroup)).Token" | tr -d '" '
}

CreateLink ()
{
  if [ $Disable = 4 ] ; then VerifyUserOrGroup ; fi
  VirtualPath="$(GetVirtualPath)$File"
  curl -sS -X POST --header "Accept: application/json" -H "AppKey: ${appkey}" -H "Authorization: Bearer ${accesstoken}" --header "As-User: " --header "Content-Type: application/json" -d "[ {\"SyncPointId\": \"$(GetSyncpointID)\", \"VirtualPath\": \"$VirtualPath\", \"ShareLinkPolicy\": $Disable, \"PasswordProtectPolicy\": $WithPass, \"Password\": \"$Password\", $(UserOrGroup)\"Message\": \"\", \"OutlookShareLinkPolicy\": \"3\", \"LinkExpirationPolicy\": $Expiration, \"LinkExpireInDays\": \"$Time\"} ]" "https://api.syncplicity.com/syncpoint/links.svc/" | python -m json.tool
}


DeleteLink ()
{
  curl -X DELETE --header "Accept: application/json" -H "AppKey: ${appkey}" -H "Authorization: Bearer ${accesstoken}" --header "As-User: " "https://api.syncplicity.com/syncpoint/link.svc/$(GetToken)"
}

GetLink ()
{
  curl -sS -X GET --header "As-User: " -H "AppKey: ${appkey}" -H "Authorization: Bearer ${accesstoken}" --header "Accept: " "https://api.syncplicity.com/syncpoint/link.svc/$(GetToken)" | xmllint --format -
}

EditLink ()
{
  VirtualPath="$(GetVirtualPath)$File"
  curl -sS -X PUT --header "As-User: " -H "AppKey: ${appkey}" -H "Authorization: Bearer ${accesstoken}" --header "Accept: " --header "Content-Type: application/json" -d "{\"SyncpointID\": \"$(GetSyncpointID)\", \"VirtualPath\": \"$VirtualPath\", \"ShareLinkPolicy\": $Disable, \"PasswordProtectPolicy\": $WithPass, \"Password\": \"$Password\", $(UserOrGroup)\"Message\": \"\", \"OutlookShareLinkPolicy\": \"3\", \"LinkExpirationPolicy\": $Expiration, \"LinkExpireInDays\": \"$Time\"}" "https://api.syncplicity.com/syncpoint/link.svc/$(GetToken)" | python -m json.tool
}

if [[ $OPTION = 'get-all-links' ]] ; then
  GetAllLinks
elif [[ $OPTION = 'create-link' ]] ; then
  CreateLink
elif [[ $OPTION = 'delete-link' ]] ; then
  DeleteLink
elif [[ $OPTION = 'get-link' ]] ; then
  GetLink
elif [[ $OPTION = 'edit-link' ]] ; then
  EditLink
else
  echo "Wrong Option!" && usage
fi
