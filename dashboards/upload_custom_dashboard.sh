#!/bin/bash

# 1. INPUT PARAMETERS
_controller_url=${1}   # hostname + /controller
_user_credentials=${2} # ${username}:${password}

_application_name=${3}
_proxy_details=${4}
_debug=${5}

_custom_dash_dir="./custom_dashboards" #I might move this into dashboard folder.. let see..
_temp_dash_dir="$_custom_dash_dir/temp"
templateAppName="ChangeApplicationName"


function func_check_http_response() {
    local http_message_body="$1"
    local string_success_response_contains="$2"
    if [[ "$http_message_body" =~ "$string_success_response_contains" ]]; then # contains
        echo "Success..."
    else
        echo "${dt} ERROR "{$http_message_body}"" >>error.log
        echo "ERROR $http_message_body"
        exit 1
    fi
}

#check if custom dashboards exist 

if [ "$(ls -A $_custom_dash_dir/*.json)" ]; then
     echo "Found custom JSON file(s) in $_custom_dash_dir"
     echo "ls -l $_custom_dash_dir/*.json" 
else
    echo "$_custom_dash_dir directory is empty. "
    echo "Please add custom dashboard JSON files to the $_custom_dash_dir directory "
    echo "Aborting.."
    exit 1
fi

#check if App exist 

allApplications=$(curl -s --user ${_user_credentials} ${_controller_url}/rest/applications?output=JSON $_proxy_details)

applicationObject=$(jq --arg appName "$_application_name" '.[] | select(.name == $appName)' <<<$allApplications)

if [ "$applicationObject" = "" ]; then
    func_check_http_response 404 "Application '"$_application_name"' not found. Aborting..."
fi

#All conditions met.. processing dashboards. 

_dasboard_API_endpoint="CustomDashboardImportExportServlet"

mkdir -p "$_temp_dash_dir" && cp -r "$_custom_dash_dir/*.json" "$_temp_dash_dir"

for _dash_file in $_temp_dash_dir; do
    echo "Processing ${_dash_file} dashboard template. Using  ${_application_name}"
    sed -i -e "s/${templateAppName}/${_application_name}/g" "${_temp_dash_dir}/${_dash_file}"
    
    echo "Uploading $_dash_file to ${_controller_url}... "

    if [ $_debug = true ]; then 
       response=$(curl -v -X POST --user ${_user_credentials} ${_controller_url}/${_dasboard_API_endpoint} -F file=@${_dash_file} ${_proxy_details})
    else
       response=$(curl -s -X POST --user ${_user_credentials} ${_controller_url}/${_dasboard_API_endpoint} -F file=@${_dash_file} ${_proxy_details})
    fi

    expected_response='"success":true'

    func_check_http_response "\{$response}" $expected_response

    echo "*********************************************************************"
    echo "The $_dash_file dashboard was create successfully. "
    echo "Please check the $_controller_url controller "
    echo "*********************************************************************"

    echo ""
    sleep 1

    # save used uploaded files
    mkdir -p "${_custom_dash_dir}/uploaded"

    cp -rf "./${_temp_dash_dir}/${_dash_file}" "${_custom_dash_dir}/uploaded/${_application_name}"-"${_dash_file}"

    #clean up - one at a time
    rm -rf "./${_temp_dash_dir}/${_dash_file}"

done
