#!/bin/sh
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

#
# executed as "db2inst1"
#

set -e
set +x

db2wh_secret=/run/secrets/db2wh_credentials
aact_secret=/run/secrets/aact_credentials

if [ ! -e ${db2wh_secret} ]; then
    echo "ERROR: Unable to locate DB2 Warehouse credentials at [${db2wh_secret}][ ]"
    exit 1
fi

if [ ! -e ${aact_secret} ]; then
    echo "ERROR: Unable to locate AACT database credentials at [${aact_secret}]."
    exit 1
fi


echo "INFO: Validating DB2 connectivity parameters" 

. /mnt/clientdir/clienthome/db2inst1/sqllib/db2profile

db2host=$(grep \"hostname\" "${db2wh_secret}" | cut -d "\"" -f 4)
db2username=$(grep \"username\" "${db2wh_secret}" | cut -d "\"" -f 4)
db2password=$(grep \"password\" "${db2wh_secret}" | cut -d "\"" -f 4)
db2db=$(grep \"db\" "${db2wh_secret}" | cut -d "\"" -f 4)
db2ssldsn=$(grep \"ssldsn\" "${db2wh_secret}" | cut -d "\"" -f 4)
db2sslport=$(echo $db2ssldsn | awk -F "PORT=" '{print $2}' | cut -d ";" -f 1)
db2alias=aact

db2cli writecfg add -database ${db2db} -host ${db2host} -port ${db2sslport}
db2cli writecfg add -dsn ${db2alias} -database ${db2db} -host ${db2host} -port ${db2sslport}
db2cli writecfg add -database ${db2db} -host ${db2host} -port ${db2sslport} -parameter "SecurityTransportMode=SSL"

db2cli validate -dsn ${db2alias} -connect -user ${db2username} -passwd ${db2password}

echo "INFO: Extracting CTGOV dashboard data." 

GE_HOME=/mnt/clientdir/clienthome/db2inst1/workdir
GE_HOME_OUTPUT="${GE_HOME}"/output

mkdir -p "${GE_HOME_OUTPUT}"

ctgov_table=CTGOV
ctgov_dump="${GE_HOME_OUTPUT}"/aact.dashboard.txt

psqlhost=$(grep "^host=" "${aact_secret}" | cut -d "=" -f 2)
psqlusername=$(grep "^user=" "${aact_secret}" | cut -d "=" -f 2)
psqlpassword=$(grep "^password=" "${aact_secret}" | cut -d "=" -f 2)
psqldb=$(grep "^dbname=" "${aact_secret}" | cut -d "=" -f 2)
psqlport=$(grep "^port=" "${aact_secret}" | cut -d "=" -f 2)
    
PGPASSWORD=${psqlpassword} psql -h ${psqlhost} -p ${psqlport} -d ${psqldb} -U ${psqlusername}  -o "${ctgov_dump}" -t -A --field-separator="|" << EOF
select s.nct_id, 
    s.overall_status,
    s.phase, 
    s.start_date, 
    s.study_first_submitted_date, 
    s.study_type, 
    s.number_of_arms, 
    s.number_of_groups, 
    s.source, 
    s.enrollment,
    s.enrollment_type,
    v.number_of_facilities,
    v.has_us_facility,
    v.has_single_facility,
    c.downcase_name, 
    case
        when (position ('ancer' in c.downcase_name  ) > 0 OR 
              position ('cinoma' in c.downcase_name  ) > 0 OR 
              position ('eukem' in c.downcase_name  ) > 0 OR 
              position ('phoma' in c.downcase_name  ) > 0 OR 
              position ('umor' in c.downcase_name  ) > 0 OR 
              position ('umour' in c.downcase_name  ) > 0 OR 
              position ('eoplasm' in c.downcase_name  ) > 0 OR 
              position ('anoma' in c.downcase_name  ) > 0) 
        then 't'
        else 'f'
    end as oncology,
    i.intervention_type, 
    i.name 
    from ctgov.studies as s 
    left outer join ctgov.calculated_values as v on s.nct_id = v.nct_id 
    left outer join ctgov.conditions as c on s.nct_id = c.nct_id 
    left outer join ctgov.interventions as i on s.nct_id = i.nct_id;
EOF

echo "INFO: Creating DB2 Warehouse table." 

create_table_sql="${GE_HOME_OUTPUT}"/aact.table.sql
cat > "${create_table_sql}" << EOF
CREATE TABLE ${ctgov_table} (
NCT_ID VARCHAR(16),
OVERALL_STATUS VARCHAR(64),
PHASE VARCHAR(64),
START_DATE DATE,
STUDY_FIRST_SUBMITTED_DATE DATE, 
STUDY_TYPE VARCHAR(64),
NUMBER_OF_ARMS INTEGER ,
NUMBER_OF_GROUPS INTEGER,
SOURCE VARCHAR(256),
ENROLLMENT INTEGER,
ENROLLMENT_TYPE VARCHAR(16),
NUMBER_OF_FACILITIES INTEGER,
HAS_US_FACILITY CHAR(1),
HAS_SINGLE_FACILITY CHAR(1),
CONDITION VARCHAR(256),
CONDITION_ONCO CHAR(1),
INTERVENTION_TYPE VARCHAR(32),
INTERVENTION_NAME VARCHAR(256));
EOF

tmpsql=$(mktemp --suffix .sql)
cat "${create_table_sql}" | tr -d "\\n"  > "${tmpsql}"
db2cli execsql -dsn ${db2alias} -user ${db2username} -passwd ${db2password} -inputsql "${tmpsql}" 2>&1
rm "${tmpsql}"

# DB2 Load
# https://www.ibm.com/support/knowledgecenter/en/SSEPGG_10.5.0/com.ibm.db2.luw.admin.cmd.doc/doc/r0008305.html#r0008305__d77859e3205

load_messages="${GE_HOME}/load.log"
rm -f "${load_messages}"
echo "Loading messages into DB2 warehouse at ${db2host}. Logs being written at [${load_messages}]"

sed -i "s/\"/\'/g" "${ctgov_dump}"
sed -i "s/ | / - /g" "${ctgov_dump}"
db2 connect to ${db2alias} user ${db2username} using ${db2password}
db2 load client from "${ctgov_dump}" of del modified by chardel~ coldel\| identityoverride anyorder messages "${load_messages}" insert into ${ctgov_table}
db2 connect reset
db2 terminate

rm -f "${ctgov_dump}"
