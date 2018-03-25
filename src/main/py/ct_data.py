#  Copyright 2018 Denilson Nastacio All Rights Reserved.
#
#  Licensed under the Apache License, Version 2.0 (the "License");
#  you may not use this file except in compliance with the License.
#  You may obtain a copy of the License at
#
#   http://www.apache.org/licenses/LICENSE-2.0
#
#  Unless required by applicable law or agreed to in writing, software
#  distributed under the License is distributed on an "AS IS" BASIS,
#  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
#  See the License for the specific language governing permissions and
#  limitations under the License.
import pandas as pd
import tensorflow as tf
import psycopg2
import configparser as cf
import numpy as np

SQL_COLUMN_NAMES = ['nct_id',
                    'start_date',
                    'study_type',
                    'enrollment',
                    'phase',
                    'overall_status']

STATUS = ['Completed',
          'Terminated']


def get_db_connection_str(db_props = 'aact.properties'):
    """Returns a psycopg2 DB database connection string"""
    config = cf.ConfigParser()
    with open(db_props) as f:
        config.readfp(f, filename=db_props)
    dbargs=""
    for k, v in config['aact.database'].items():
        dbargs=dbargs + k + "=" + v + " "
    return dbargs    


def train_validate_test_split(df, train_percent=.6, validate_percent=.2, seed=None):
    """Splits the original CT items into 3 sets: training, validation, testing"""
    np.random.seed(seed)
    perm = np.random.permutation(df.index)
    m = len(df.index)
    train_end = int(train_percent * m)
    validate_end = int(validate_percent * m) + train_end
    train = df.ix[perm[:train_end]]
    validate = df.ix[perm[train_end:validate_end]]
    test = df.ix[perm[validate_end:]]
    return train, validate, test


def load_data(y_name='status', db_props='aact.properties'):
    """Returns the CT dataset as (train_x, train_y), (test_x, test_y), , (validate_x, validate_y)."""

    dbargs=get_db_connection_str(db_props)
    conn = psycopg2.connect(dbargs)

    sqlstr= \
    "SELECT s." + ",s.".join(SQL_COLUMN_NAMES) + ", sp.agency_class as sponsor_type, cv.number_of_facilities, e.gender, " + \
    "    cv.has_us_facility, CASE WHEN s.brief_title LIKE '%age III%' THEN '1' WHEN s.brief_title LIKE '%age IV%' THEN '2' ELSE 0 END as condition_stage, " + \
    "    d.allocation, d.intervention_model, d.primary_purpose, i2.drug_recency, bs.description, " + \
    "    count(dgi.id) as design_group_intervention_count, count(distinct(i.intervention_type)) as intervention_type_count, " + \
    "    count(distinct(sp2.name)) as sponsor_count " + \
    "FROM studies as s, calculated_values as cv, eligibilities as e, interventions as i, " + \
    "    sponsors as sp, sponsors as sp2, design_group_interventions as dgi, designs as d, brief_summaries as bs," + \
    "    (SELECT i.nct_id as nct_id, min(s.study_first_submitted_date) as drug_recency, count(distinct(i.nct_id)) as drug_frequency " + \
    "    FROM studies as s, interventions as i" + \
    "    WHERE s.nct_id = i.nct_id AND intervention_type='Drug' " + \
    "    GROUP BY i.nct_id) as i2 " + \
    "WHERE s.nct_id=cv.nct_id AND s.nct_id=sp.nct_id AND s.nct_id=i.nct_id AND s.nct_id=sp2.nct_id AND s.nct_id=e.nct_id  AND s.nct_id=dgi.nct_id AND s.nct_id=d.nct_id AND s.nct_id=i2.nct_id AND s.nct_id=bs.nct_id " + \
    "AND s.start_date > '2009-01-01' " + \
    "AND (s.brief_title LIKE '%ancer%' OR s.brief_title LIKE '%umor%' OR s.brief_title LIKE '%umour%' OR s.brief_title LIKE '%eukemia%' OR s.brief_title LIKE '%yeloma%' OR s.brief_title LIKE '%ymphoma%' OR s.brief_title LIKE '%arcoma%')" + \
    "AND s.overall_status in ('Completed', 'Terminated') " + \
    "AND s.enrollment IS NOT NULL AND cv.number_of_facilities > 0  " + \
    "AND sp.lead_or_collaborator = 'lead' " + \
    "GROUP BY s." + ",s.".join(SQL_COLUMN_NAMES) + ", sponsor_type, cv.number_of_facilities, e.gender, cv.has_us_facility, s.brief_title, e.criteria, " + \
    "    d.allocation, d.intervention_model, d.primary_purpose, i2.drug_recency, bs.description "
    print(sqlstr)    
    df = pd.read_sql_query(sql=sqlstr, 
                           con=conn,
                           index_col='nct_id', 
                           parse_dates={'start_date': '%Y-%m-%d', 'drug_recency': '%Y-%m-%d'})
    conn.close()

#     df_sponsors = df1['source'].value_counts()
#     df=df1.join(df_sponsors,
#                 on='source',
#                 rsuffix='_local')

#    print(df.groupby('phase').count())

    df['start_epoch'] = df.start_date.dt.year
    df['drug_epoch'] = df.drug_recency.dt.year
    df['study_type_category'] = 0
    df['agency_type_category'] = 0
    df['gender_category'] = 0
    df['allocation_type'] = 0
#     df['intervention_model_type'] = 0
    df['primary_purpose_type'] = 0
    df['status'] = 0
    df.loc[df.study_type == 'Expanded Access', 'study_type_category'] = 1
    df.loc[df.study_type == 'Interventional', 'study_type_category'] = 2
    df.loc[df.study_type == 'Observational', 'study_type_category'] = 3
    df.loc[df.study_type == 'Observational [Patient Registry]', 'study_type_category'] = 4
    df.loc[df.overall_status == 'Completed', 'status'] = 0
    df.loc[df.overall_status == 'Terminated', 'status'] = 1
    df.loc[df.sponsor_type == 'U.S. Fed', 'agency_type_category'] = 0
    df.loc[df.sponsor_type == 'NIH', 'agency_type_category'] = 1
    df.loc[df.sponsor_type == 'Industry', 'agency_type_category'] = 2
    df.loc[df.sponsor_type == 'Other', 'agency_type_category'] = 3
    df.loc[df.gender == 'Male', 'gender_category'] = 1
    df.loc[df.gender == 'Female', 'gender_category'] = 2
    df.loc[df.allocation == 'Randomized', 'allocation_type'] = 1
    df.loc[df.description.str.contains('randomized'), 'allocation_type'] = 1
    df.loc[df.allocation == 'Non-Randomized', 'allocation_type'] = 2
    df.loc[df.description.str.contains('non-randomized'), 'allocation_type'] = 2
#     df.loc[df.intervention_model == 'Crossover Assignment', 'intervention_model_type'] = 1
#     df.loc[df.intervention_model == 'Factorial Assignment', 'intervention_model_type'] = 2
#     df.loc[df.intervention_model == 'Parallel Assignment', 'intervention_model_type'] = 3
#     df.loc[df.intervention_model == 'Sequential Assignment', 'intervention_model_type'] = 4
#     df.loc[df.intervention_model == 'Single Group Assignment', 'intervention_model_type'] = 5
    df.loc[df.primary_purpose == 'Basic Science', 'primary_purpose_type'] = 1
    df.loc[df.primary_purpose == 'Device Feasibility', 'primary_purpose_type'] = 2
    df.loc[df.primary_purpose == 'Diagnostic', 'primary_purpose_type'] = 3
    df.loc[df.primary_purpose == 'Educational/Counseling/Training', 'primary_purpose_type'] = 4
    df.loc[df.primary_purpose == 'Health Services Research', 'primary_purpose_type'] = 5
    df.loc[df.primary_purpose == 'Prevention', 'primary_purpose_type'] = 6
    df.loc[df.primary_purpose == 'Screening', 'primary_purpose_type'] = 7
    df.loc[df.primary_purpose == 'Supportive Care', 'primary_purpose_type'] = 8
    df.loc[df.primary_purpose == 'Treatment', 'primary_purpose_type'] = 9

    df.drop(columns=['start_date','overall_status','sponsor_type', 'gender', 'phase', 'study_type', 
                     'has_us_facility', 'allocation', 'intervention_model', 'primary_purpose', 'drug_recency','description'], inplace=True)

    train, validate, test = train_validate_test_split(df, 0.7, 0.005)

    train_x, train_y = train, train.pop(y_name)
    test_x, test_y = test, test.pop(y_name)
    validate_x, validate_y = validate, validate.pop(y_name)

    return (train_x, train_y), (test_x, test_y), (validate_x, validate_y)
    

def train_input_fn(features, labels, batch_size):
    """An input function for training"""
    # Convert the inputs to a Dataset.
    dataset = tf.data.Dataset.from_tensor_slices((dict(features), labels))

    # Shuffle, repeat, and batch the examples.
    dataset = dataset.shuffle(1000).repeat().batch(batch_size)

    # Return the dataset.
    return dataset


def eval_input_fn(features, labels, batch_size):
    """An input function for evaluation or prediction"""
    features=dict(features)
    if labels is None:
        # No labels, use only features.
        inputs = features
    else:
        inputs = (features, labels)

    # Convert the inputs to a Dataset.
    dataset = tf.data.Dataset.from_tensor_slices(inputs)

    # Batch the examples
    assert batch_size is not None, "batch_size must not be None"
    dataset = dataset.batch(batch_size)

    # Return the dataset.
    return dataset
