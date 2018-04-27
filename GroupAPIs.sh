#!/bin/bash

function usage () {
        echo
        echo "Usage: ./UserAPIs.sh -o [Option] -u Username -f \"First Name\" -l \"Last Name\" -p Password -e Email -t Type -r Role -d [0/1] -a [0/1] "
        echo
        echo "Options:"
        echo "-o - options are:"
        echo
        echo "show-users - Show all users."
        echo "create-user - Create new user. Must input username and type."
        echo "delete-user - Delete user."
        echo "show-user - Show user details."
        echo "edit-user - Edit single user. Enable/Disable user. Activate/Deactivate user. Change email (with -e), first or last name, password or role."
        echo "edit-users - Edit multiple users. Can't enable/disable or activate/deactivate. Can change account type."
        echo "company-details - Show company details."
        echo
        echo "-u - Username (email)."
        echo "-f - First Name. If the name has spaces it must be inside double quotes."
        echo "-l - Last Name. If the name has spaces it must be inside double quotes."
        echo "-p - Password for account."
        echo "-e - Email for account."
        echo "-t - Type of account. Account types are:"
        echo
        echo "                3 - PaidBusiness: A user who is subscribed to Syncplicity as part of a business account."
        echo "                7 - LimitedBusiness: users who have been added to a company account but not yet provided their personal details."
        echo "               14 - TrialBusiness: A user who is subscribed to Syncplicity as part of a business trial account and hasn't previous subscription."
        echo "               16 - PendingBusiness: A user who is suggested to be added to a company account, but not yet approved by a company administrator."
        echo
        echo "-r - Role of account. Possible users roles:"
        echo "                1 - AccountOwner (Global administrator and account owner)."
        echo "                2 - Administrator (Global administrator)."
        echo "                3 - Support (Support tools)."
        echo "                4 - ReportViewer (Report viewer)."
        echo "                5 - SupportAdmin (Support administrator)."
        echo "                6 - EDiscoveryAdmin (E-Discovery administrator)."
        echo
        echo "-d - Disabled flag. 1 for disabled, 0 for enabled. Default value is 0."
        echo "-a - Active flag. 1 for active 0 for inactive. Default value is 1."
        echo
        echo "Examples:"
        echo "./UserAPIs.sh -o show-users"
        echo "./UserAPIs.sh -o create-user -u Username -f \"First Name\" -l \"Last Name\" -p Password -t Type -r Role"
        echo "./UserAPIs.sh -o edit-user -u Username -f \"First Name\" -l \"Last Name\" -p Password -r Role -e Email -d [0/1] -a [0/1]"
        exit 2


}

Disable=0
Active=1

while getopts "o:u:g:l:p:e:t:r:d:a:h" opt
do
        case ${opt} in
                o) OPTION=$OPTARG ;;
                u) USER=$OPTARG ;;
                g) Group=$OPTARG ;;
                l) LastName=$OPTARG ;;
                p) Password=$OPTARG ;;
                e) Email=$OPTARG ;;
                t) Type=$OPTARG ;;
                r) Role=$OPTARG ;;
                d) Disable=$OPTARG ;;
                a) Active=$OPTARG ;;
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
else
  echo "Wrong Option!" && usage
fi
