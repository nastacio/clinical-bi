############################################################################# {COPYRIGHT-TOP} ####
#  Copyright 2018 Denilson Nastacio
#
#  Licensed under the Apache License, Version 2.0 (the "License");
#  you may not use this file except in compliance with the License.
#  You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
#  Unless required by applicable law or agreed to in writing, software
#  distributed under the License is distributed on an "AS IS" BASIS,
#  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
#  See the License for the specific language governing permissions and
#  limitations under the License.
############################################################################# {COPYRIGHT-END} ####

FROM store/ibmcorp/db2wh_ce:v2.10.0-db2wh_client-linux

ADD https://jdbc.postgresql.org/download/postgresql-42.2.4.jar /usr/local/lib
COPY scripts/* /usr/local/bin/

RUN chmod ag+r /usr/local/lib/*.jar && \
    yum install postgresql -y
