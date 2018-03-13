#!/bin/sh

# ------------------------------------------------------------------------
# Copyright 2018 WSO2, Inc. (http://wso2.com)
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
# http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License
# ------------------------------------------------------------------------
set -e

wso2_server=wso2is
wso2_server_version=5.4.1

user=wso2carbon
user_id=802
group=wso2
group_id=802

working_directory=/home/${user}
wso2_server_home=${working_directory}/${wso2_server}-${wso2_server_version}
volumes=${working_directory}/volumes

docker_container_ip=$(awk 'END{print $1}' /etc/hosts)

# check if the WSO2 non-root user has been created
id ${user_id} >/dev/null 2>&1
if [ "$?" -gt 0 ]; then
    echo "WSO2 Docker non-root user does not exist"
    exit 1
fi

# check if the WSO2 non-root group has been created
if ! [ $(getent group ${group_id}) ]; then
    echo "WSO2 Docker non-root group does not exist"
    exit 1
fi

# check if the WSO2 non-root user home exists
if test ! -d ${working_directory}; then
    echo "WSO2 Docker non-root user home does not exist"
    exit 1
fi

# check if the WSO2 product home exists
if test ! -d ${wso2_server_home}; then
    echo "WSO2 Docker product home does not exist"
    exit 1
fi

# check if any changed configuration files have been mounted
if test -d ${volumes}/repository/conf; then
    # if any file changes have been mounted, copy the WSO2 configuration files recursively
    cp -r ${volumes}/repository/conf/* ${wso2_server_home}/repository/conf
fi

# check if the external library directories have been mounted
# if mounted, recursively copy the external libraries to original directories within the product home
if test -d ${volumes}/repository/components/dropins; then
    cp -r ${volumes}/repository/components/dropins/* ${wso2_server_home}/repository/components/dropins
fi

if test -d ${volumes}/repository/components/extensions; then
    cp -r ${volumes}/repository/components/extensions/* ${wso2_server_home}/repository/components/extensions
fi

if test -d ${volumes}/repository/components/lib; then
    cp -r ${volumes}/repository/components/lib/* ${wso2_server_home}/repository/components/lib
fi

# set the Docker container IP as the `localMemberHost` under axis2.xml clustering configurations
if [[ ${CLUSTERING_ENABLED} == true ]]; then
    sed -i "s#<parameter\ name=\"localMemberHost\".*#<parameter\ name=\"localMemberHost\">${docker_container_ip}<\/parameter>#" ${wso2_server_home}/repository/conf/axis2/axis2.xml
    if [[ $? == 0 ]]; then
        echo "Successfully updated localMemberHost with ${docker_container_ip}"
    else
        echo "Error occurred while updating localMemberHost with ${docker_container_ip}"
    fi
fi

# set the ownership of the WSO2 product server home
chown -R ${user}:${group} ${wso2_server_home}

# start the WSO2 Carbon server
sh ${wso2_server_home}/bin/wso2server.sh
