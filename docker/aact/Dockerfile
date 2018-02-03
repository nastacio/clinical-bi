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

# https://hub.docker.com/_/postgres/
FROM postgres:9.6.6

ARG aact_version=20180201
ARG aact_filename=${aact_version}_clinical_trials.zip
ARG aact_static_psql_url=https://aact.ctti-clinicaltrials.org/static/static_db_copies/${aact_filename}

RUN \
  apt-get update && \
  apt-get install curl unzip -y && \
  curl ${aact_static_psql_url} > /tmp/${aact_filename} && \
  mkdir -p /tmp/aact && \
  unzip /tmp/${aact_filename} -d /tmp/aact && \
  rm /tmp/${aact_filename}

COPY docker-entrypoint-initdb.d/* /docker-entrypoint-initdb.d

