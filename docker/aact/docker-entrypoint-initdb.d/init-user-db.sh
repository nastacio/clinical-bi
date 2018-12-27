############################################################################# {COPYRIGHT-TOP} ####
#  Copyright 2018 
#  Denilson Nastacio
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

#!/bin/bash
set -e

# Removed --clean --create from the AACT instructions since the Docker postgres
# startup will already have created the database
aactDump="${AACT_DUMP_DIR}/postgres_data.dmp"
pg_restore -e -v -O -x --dbname=aact --no-owner "${aactDump}"
rm "${aactDump}"

psql -d aact -c "create user ${READONLY_USER} password '${READONLY_PASSWORD}'"
psql -d aact -c "grant CONNECT on database aact to ${READONLY_USER}"
psql -d aact -c "grant select on all tables in schema ctgov to ${READONLY_USER}"
psql -d aact -c "grant usage on schema ctgov to ${READONLY_USER}" 

# https://stackoverflow.com/questions/2875610/permanently-set-postgresql-schema-path
psql -d aact -c "alter database aact SET search_path TO ctgov"

