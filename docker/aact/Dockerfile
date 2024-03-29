############################################################################# {COPYRIGHT-TOP} ####
#  Copyright 2018,2023 Denilson Nastacio
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
FROM postgres

ARG aact_version=${aact_version:-20230430}
ARG aact_filename=${aact_version}_clinical_trials.zip
ARG aact_static_psql_url=https://aact.ctti-clinicaltrials.org/static/static_db_copies/monthly/${aact_filename}

ENV AACT_DUMP_DIR=/tmp/aact

RUN \
  apt-get update && \
  apt-get install curl unzip -y && \
  echo "Retrieving AACT db dump from ${aact_static_psql_url}" && \
  curl -L ${aact_static_psql_url} > /tmp/${aact_filename} && \
  mkdir -p "${AACT_DUMP_DIR}" && \
  unzip /tmp/${aact_filename} -d "${AACT_DUMP_DIR}" && \
  rm /tmp/${aact_filename} && \
  chown -R postgres "${AACT_DUMP_DIR}" && \
  echo "Applying image security patches" && \
  apt-get install --only-upgrade exim4 libxml2 sensible-utils -y && \
  touch /var/log/faillog

COPY docker-entrypoint-initdb.d/* /docker-entrypoint-initdb.d
