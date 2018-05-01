#!/bin/bash

function usage () {
        echo
        echo "Usage: ./GroupAPIs.sh -o [Option] -u Username -g \"Group Name\" -f \"File Name\""
        echo
        echo "Options:"
        echo "-o - options are:"
        echo
        echo "get-all-groups - Show all groups."
        echo "get-user-groups - Get groups of certain user."
        echo "delete-group - Delete group."
        echo "get-group-members - Get all members of a certain group."
        echo "get-group-member - Check if user is a member of a group."
        echo "delete-from-group - Remove user from a certain group."
        echo "add-to-group - Add user to a certain group."
        echo "create-group - Create a new group."
        echo "edit-group - Edit am existing group."
        echo
        echo "-u - Username (email)."
        echo "-g - Group name. Requires quotes if more than one word."
        echo "-f - File name. Requires quotes if more than one word. Used for group creation or edit."
        echo
        echo "Examples:"
        echo "./GroupAPIs.sh -o get-all-groups"
        echo "./GroupAPIs.sh -o add-to-group -u Username -g \"Group Name\""
        echo
        exit 2


}


while getopts "o:u:g:f:h" opt
do
        case ${opt} in
                o) OPTION=$OPTARG ;;
                u) USER=$OPTARG ;;
                g) Group=$OPTARG ;;
                f) File=$OPTARG ;;
                h) usage ;;
        esac
done

DATE=$(date +"%d-%m-%y-%H-%M-%S")

appkey=$(grep 'App Key' /root/DemoAccount | cut -d : -f2 | tr -d ' ')
appsecret=$(grep 'App Secret' /root/DemoAccount | cut -d : -f2 | tr -d ' ')
usersyncapptoken=$(grep 'Application Token' /root/DemoAccount | cut -d : -f2 | tr -d ' ')
oauthbasic=$(echo -n "${appkey}:${appsecret}" | base64)

oauthresult=$(curl -sS -X POST https://api.syncplicity.com/oauth/token -H 'Authorization: Basic '${oauthbasic} -H "Sync-App-Token: ${usersyncapptoken}" -d 'grant_type=client_credentials')

accesstoken=$(echo ${oauthresult} | sed -e 's/[{}"]/''/g' | awk -v RS=',' -F: '/^access_token/ {print $2}')
companyID=$(echo ${oauthresult} | sed -e 's/[{}"]/''/g' | awk -v RS=',' -F: '/^user_company_id/ {print $2}')


#Show all groups
GetAllGroups ()
{
  curl -sS -X GET -H "AppKey: ${appkey}" -H "Authorization: Bearer ${accesstoken}" --header "Accept: application/json" "https://api.syncplicity.com/provisioning/groups.svc/${companyID}/groups" | python -m json.tool
}

GetGroupID ()
{
  GetAllGroups | jq ".[] | select(.Name==\"$Group\")" | jq .Id | tr -d '" '
}

GetUserGroups ()
{
  curl -sS -X GET -H "AppKey: ${appkey}" -H "Authorization: Bearer ${accesstoken}" --header "Accept: application/json" "https://api.syncplicity.com/provisioning/user_groups.svc/user/$(./UserAPIs.sh -o show-user -u $USER | jq .Id | tr -d '" ')/groups" | python -m json.tool
}

DeleteGroup ()
{
#Delete Group
  curl -X DELETE -H "AppKey: ${appkey}" -H "Authorization: Bearer ${accesstoken}" "https://api.syncplicity.com/provisioning/group.svc/$(GetGroupID)"
}

GetGroupMembers ()
{
#Show group members
  curl -sS -X GET -H "AppKey: ${appkey}" -H "Authorization: Bearer ${accesstoken}" --header "Accept: application/json" "https://api.syncplicity.com/provisioning/group_members.svc/$(GetGroupID)" | python -m json.tool
}

GetGroupMember ()
{
#Show group member
  curl -sS -X GET --header "Accept: application/json" -H "AppKey: ${appkey}" -H "Authorization: Bearer ${accesstoken}" "https://api.syncplicity.com/provisioning/group_member.svc/$(GetGroupID)/member/$USER" | python -m json.tool
}

DeleteuserFromGroup ()
{
#Delete user from group
  curl -X DELETE -H "AppKey: ${appkey}" -H "Authorization: Bearer ${accesstoken}" "https://api.syncplicity.com/provisioning/group_member.svc/$(GetGroupID)/member/$USER"
}

AddUserToGroup ()
{
  curl -sS -X POST -H "AppKey: ${appkey}" -H "Authorization: Bearer ${accesstoken}" --header "Accept: application/json" --header "Content-Type: application/json" -d "[ {\"EmailAddress\": \"$USER\"} ]" "https://api.syncplicity.com/provisioning/group_members.svc/$(GetGroupID)"
}

CreateGroup ()
{
  cp $File $File-$DATE
  sed -i '1s/^/[ /' $File-$DATE
  sed -i "\$c} ]" $File-$DATE
  curl -sS -X POST -H "AppKey: ${appkey}" -H "Authorization: Bearer ${accesstoken}" --header "Accept: application/json" --header "Content-Type: application/json" -d @$File-$DATE "https://api.syncplicity.com/provisioning/groups.svc/${companyID}/groups" | python -m json.tool
  rm -f $File-$DATE
}

EditGroup ()
{
  curl -v -sS -X PUT -H "AppKey: ${appkey}" -H "Authorization: Bearer ${accesstoken}" --header "Accept: application/json" --header "Content-Type: application/json" -d @$File "https://api.syncplicity.com/provisioning/group.svc/$(GetGroupID)"
}

if [[ $OPTION = 'get-user-groups' ]] ; then
  GetUserGroups
elif [[ $OPTION = 'get-all-groups' ]] ; then
  GetAllGroups
elif [[ $OPTION = 'delete-group' ]] ; then
  DeleteGroup
elif [[ $OPTION = 'get-group-members' ]] ; then
  GetGroupMembers
elif [[ $OPTION = 'get-group-member' ]] ; then
  GetGroupMember
elif [[ $OPTION = 'delete-from-group' ]] ; then
  DeleteuserFromGroup
elif [[ $OPTION = 'add-to-group' ]] ; then
  AddUserToGroup
elif [[ $OPTION = 'create-group' ]] ; then
  CreateGroup
elif [[ $OPTION = 'edit-group' ]] ; then
  EditGroup
else
  echo "Wrong Option!" && usage
fi
