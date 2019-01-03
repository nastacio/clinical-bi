############################################################################# {COPYRIGHT-TOP} ####
#  Copyright 2018,2019 
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

# https://stackoverflow.com/questions/2875610/permanently-set-postgresql-schema-path
psql -d aact -c "alter database aact SET search_path TO ctgov"

#
# Create and populate new conditions_calculated_values
#

psql -d aact -c "create table ctgov.conditions_calculated_values(
 downcase_name character varying NOT NULL PRIMARY KEY,
 is_oncology boolean,
 total_interventional_studies integer,
 completed_interventional_studies integer,
 terminated_interventional_studies integer,
 withdrawn_interventional_studies integer,
 intervention_completion_ratio real)"

psql -d aact -c "insert into ctgov.conditions_calculated_values (
    downcase_name, 
    is_oncology, 
    total_interventional_studies, 
    completed_interventional_studies,
    terminated_interventional_studies,
    withdrawn_interventional_studies,
    intervention_completion_ratio)
select
    c.downcase_name as downcase_name,
    case when 
            position('ancer' in c.downcase_name) > 0 or
            position('cinoma' in c.downcase_name) > 0 or
            position('eukem' in c.downcase_name) > 0 or
            position('phoma' in c.downcase_name) > 0 or
            position('umor' in c.downcase_name) > 0 or 
            position('umour' in c.downcase_name) > 0 or 
            position('eoplasm' in c.downcase_name) > 0 or 
            position('anoma' in c.downcase_name) > 0 
         then true 
         else false
         end as is_oncology,
    count(distinct s_total.nct_id) as total_interventional_studies,
    count(distinct s_completed.nct_id) as completed_interventional_studies,
    count(distinct s_terminated.nct_id) as terminated_interventional_studies,
    count(distinct s_withdrawn.nct_id) as withdrawn_interventional_studies,
    case when 
            (count(distinct s_completed.nct_id) +  count(distinct s_terminated.nct_id) + count (distinct s_withdrawn.nct_id)) > 0 
         then (cast (count(distinct s_completed.nct_id) as real)/(count(distinct s_completed.nct_id) +  count(distinct s_terminated.nct_id) + count (distinct s_withdrawn.nct_id))) 
         else (0) 
         end as intervention_completion_ratio
from ctgov.conditions as c
inner join ctgov.studies as s on c.nct_id=s.nct_id
left outer join ctgov.studies as s_total on c.nct_id=s_total.nct_id and s_total.study_type='Interventional'
left outer join ctgov.studies as s_completed on c.nct_id=s_completed.nct_id and s_completed.overall_status='Completed' and s_completed.study_type='Interventional'
left outer join ctgov.studies as s_terminated on c.nct_id=s_terminated.nct_id and s_terminated.overall_status='Terminated' and s_terminated.study_type='Interventional'
left outer join ctgov.studies as s_withdrawn on c.nct_id=s_withdrawn.nct_id and s_withdrawn.overall_status='Withdrawn' and s_withdrawn.study_type='Interventional'
group by 
    c.downcase_name"

psql -d aact -c "create index conditions_calculated_values_idx_downcase_name 
ON ctgov.conditions_calculated_values (downcase_name)"


#
# Modifications to calculated_values table
#
psql -d aact -c "alter table ctgov.calculated_values add column is_oncology boolean"
psql -d aact -c "alter table ctgov.calculated_values add column number_of_conditions integer"
psql -d aact -c "alter table ctgov.calculated_values add column average_condition_completion_ratio real"

psql -d aact -c "create table ctgov.temp_calculated_values (
 nct_id character varying NULL,
 is_oncology boolean,
 number_of_conditions integer,
 average_condition_completion_ratio real)"

psql -d aact -c "insert into ctgov.temp_calculated_values
( nct_id, 
  is_oncology, 
  number_of_conditions,
  average_condition_completion_ratio
)
select
        s_join.nct_id as nct_id,
        bool_or(ce.is_oncology) as is_oncology,
        count(distinct c.downcase_name) as number_of_conditions,
        avg(ce.intervention_completion_ratio) as average_condition_completion_ratio
    from
        ctgov.studies as s_join,
        ctgov.conditions as c, 
        ctgov.conditions_calculated_values as ce
    where 
        s_join.nct_id = c.nct_id and
        c.downcase_name = ce.downcase_name
    group by
        s_join.nct_id"
psql -d aact -c "create index studies_calculated_values_idx_nct_id 
ON ctgov.temp_calculated_values (nct_id)"

psql -d aact -c "update ctgov.calculated_values
set is_oncology = new_studies_values.is_oncology, 
    number_of_conditions = new_studies_values.number_of_conditions,
    average_condition_completion_ratio = new_studies_values.average_condition_completion_ratio
from
    ctgov.temp_calculated_values as new_studies_values
where
    ctgov.calculated_values.nct_id = new_studies_values.nct_id"
    
psql -d aact -c "drop table ctgov.temp_calculated_values"

# 
# Granting proper permissions to READONLY_USER across the whole schema
#

psql -d aact -c "create user ${READONLY_USER} password '${READONLY_PASSWORD}'"
psql -d aact -c "grant CONNECT on database aact to ${READONLY_USER}"

psql -d aact -c "grant select on all tables in schema ctgov to ${READONLY_USER}"
psql -d aact -c "grant usage on schema ctgov to ${READONLY_USER}" 
