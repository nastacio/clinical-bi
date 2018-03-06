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
from __future__ import absolute_import
from __future__ import division
from __future__ import print_function

import argparse
import tensorflow as tf

import ct_data


parser = argparse.ArgumentParser()
parser.add_argument('--batch_size', default=100, type=int, help='batch size')
parser.add_argument('--train_steps', default=1000, type=int,
                    help='number of training steps')

def main(argv):
    args = parser.parse_args(argv[1:])

    # Fetch the data
    (train_x, train_y), (test_x, test_y),  (validate_x, validate_y) = ct_data.load_data()

    epoch_feature_column = tf.feature_column.numeric_column("start_epoch")
    bucketized_start_feature_column = tf.feature_column.bucketized_column(
        source_column = epoch_feature_column,
        boundaries = [2005, 2008, 2011, 2014, 2017])
    completion_epoch_feature_column = tf.feature_column.numeric_column("completion_epoch")
    bucketized_completion_feature_column = tf.feature_column.bucketized_column(
        source_column = completion_epoch_feature_column,
        boundaries = [2005, 2008, 2011, 2014, 2017])

    # Feature columns describe how to use the input.
    my_feature_columns = []
    for key in train_x.keys():
        if key == 'start_epoch':
            my_feature_columns.append(bucketized_start_feature_column)
        elif key == 'completion_epoch':
            my_feature_columns.append(bucketized_completion_feature_column)
        else:
            my_feature_columns.append(tf.feature_column.numeric_column(key=key))

    # Build 2 hidden layer DNN with 10, 10 units respectively.
    classifier = tf.estimator.DNNClassifier(
        feature_columns=my_feature_columns,
        hidden_units=[100,100],
        n_classes=2)

    # Train the Model.
    classifier.train(
        input_fn=lambda:ct_data.train_input_fn(train_x, train_y,
                                                 args.batch_size),
        steps=args.train_steps)

    # Evaluate the model.
    eval_result = classifier.evaluate(
        input_fn=lambda:ct_data.eval_input_fn(test_x, test_y,
                                                args.batch_size))

    print('\nTest set accuracy: {accuracy:0.3f}\n'.format(**eval_result))

    # Generate predictions from the model
    expected = validate_y
    predict_x = validate_x

    predictions = classifier.predict(
        input_fn=lambda:ct_data.eval_input_fn(predict_x,
                                                labels=None,
                                                batch_size=args.batch_size))
    for pred_dict, expec, nct_id in zip(predictions, expected, expected.index):
        template = ('\nPrediction for {} is "{}" ({:.1f}%), expected "{}"')

        class_id = pred_dict['class_ids'][0]
        probability = pred_dict['probabilities'][class_id]

        print(template.format(nct_id,
                              ct_data.STATUS[class_id],
                              100 * probability, ct_data.STATUS[expec]))


if __name__ == '__main__':
    tf.logging.set_verbosity(tf.logging.INFO)
    tf.app.run(main)
