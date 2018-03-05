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

SQL_COLUMN_NAMES = ['start_date',
                    'completion_date',
                    'study_type',
                    'enrollment',
                    'overall_status']
TF_COLUMN_NAME = ['start_epoch',
                  'completion_epoch',
                  'study_scalar',
                  'enrollment',
                  'status']

STATUS = ['Completed', 
          'Terminated']


def get_db_connection_str():
    """Returns a psycopg2 DB database connection string"""
    config = cf.ConfigParser()
    with open(r'aact.properties') as f:
        config.read_string(f.read())
    dbargs=""
    for k, v in config['aact.database'].items():
        dbargs=dbargs + k + "=" + v + " "
    return dbargs    


def train_validate_test_split(df, train_percent=.6, validate_percent=.2, seed=None):
    np.random.seed(seed)
    perm = np.random.permutation(df.index)
    m = len(df.index)
    train_end = int(train_percent * m)
    validate_end = int(validate_percent * m) + train_end
    train = df.ix[perm[:train_end]]
    validate = df.ix[perm[train_end:validate_end]]
    test = df.ix[perm[validate_end:]]
    return train, validate, test


def load_data(y_name='status'):
    """Returns the CT dataset as (train_x, train_y), (test_x, test_y), , (validate_x, validate_y)."""

    sqlstr= \
    "SELECT " + ",s.".join(SQL_COLUMN_NAMES) + " FROM studies as s, conditions as c " + \
    "WHERE s.start_date > '1980-01-01' AND s.completion_date > '1980-01-01' " + \
    "AND s.nct_id=c.nct_id AND c.downcase_name = 'lung cancer' " + \
    "AND (s.overall_status='Completed' OR s.overall_status='Terminated') " + \
    "AND s.study_type in ('Observational', 'Interventional') " + \
    "AND s.enrollment > 0"

    dbargs=get_db_connection_str()
    conn = psycopg2.connect(dbargs)
    df = pd.read_sql_query(sql=sqlstr, 
                           con=conn, 
                           parse_dates={'start_date': '%Y-%m-%d', 'completion_date': '%Y-%m-%d'})
    conn.close()

    df['start_epoch'] = df.start_date.dt.month
    df['completion_epoch'] = df.completion_date.dt.month
    df['study_scalar'] = 0
    df['status'] = 0
    df.loc[df.study_type == 'Interventional', 'study_scalar'] = 0
    df.loc[df.study_type == 'Observational', 'study_scalar'] = 1
    df.loc[df.overall_status == 'Completed', 'status'] = 0
    df.loc[df.overall_status == 'Terminated', 'status'] = 1
    
    df.drop(columns=['start_date','completion_date','overall_status','study_type'], inplace=True)

    train, validate, test = train_validate_test_split(df, 0.7, 0.01)

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
