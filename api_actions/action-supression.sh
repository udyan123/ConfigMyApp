#!/bin/bash

# 1. INPUT PARAMETERS
_controller_url=${1} # hostname + /controller
_user_credentials=${2} # ${username}:${password}

_action_supression_start=${3}
_action_supression_duration=${4} 

_application_name=${5}

# 2. FUNCTIONS
function func_check_http_response(){
    local http_message_body="$1"
    local string_success_response_contains="$2"
    if [[ "$http_message_body" =~ "$string_success_response_contains" ]]; then # contains
            echo "*********************************************************************"
            echo "Success"
            echo "*********************************************************************"
        else
            echo "${dt} ERROR "{$http_message_body}"" >> error.log
            echo "ERROR $http_message_body"
            exit 1
        fi
}

# 3. PREPARE REQUEST
dt=$(date '+%Y-%m-%d_%H-%M-%S')

_payload_path="./api_actions/uploaded/action-supression-payload-${dt}.json"
_template_path="./api_actions/action-supression-payload.json"

_header="Content-Type: application/json; charset=utf8"

_action_supression_name="CMA-supression-${dt}"


echo | date -d "today" >/dev/null 2>&1
if [ $? -eq 0 ]; then
    # GNU
    _action_supression_end=$(date -d "${_action_supression_start} +${_action_supression_duration} minutes" "+%FT%T+0000")
else
    # Mac
    _action_supression_end=$(date -j -v +${_action_supression_duration}M -f "%Y-%M-%dT%H:%M:%S+0000" "${_action_supression_start}" "+%FT%T+0000")
fi

# populate the payload template
sed -e "s/_action_supression_name/${_action_supression_name}/g" -e "s/_action_supression_start/${_action_supression_start}/g" -e "s/_action_supression_end/${_action_supression_end}/g" "${_template_path}" > "${_payload_path}"

# application id
allApplications=$(curl -s --user ${_user_credentials} ${_controller_url}/rest/applications?output=JSON)

applicationObject=$(jq --arg appName "$_application_name" '.[] | select(.name == $appName)' <<<$allApplications)

if [ "$applicationObject" = "" ]; then
    func_check_http_status 404 "Application '"$_application_name"' not found. Aborting..."
fi

application_id=$(jq '.id' <<< $applicationObject)
_resource_url="alerting/rest/v1/applications/${application_id}/action-suppressions"

# 4. SEND A CREATE REQUEST
response=$(curl -v -X POST --user $_user_credentials $_controller_url/$_resource_url -H "${_header}" --data "@${_payload_path}" )

# 5. CHECK RESULT
expected_response='"id":' # returns id on success
func_check_http_response "\{$response}" $expected_response
 
# echo "response is: $response"
