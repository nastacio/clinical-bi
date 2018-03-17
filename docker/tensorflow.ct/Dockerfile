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

FROM gcr.io/tensorflow/tensorflow

RUN \
    curl https://codeload.github.com/nastacio/clinical-bi/zip/master > /tmp/clinical-bi.zip && \
    unzip -q /tmp/clinical-bi.zip -d /usr/local && \
    cd /usr/local/clinical-bi-master/src/main/py && \
    pip install psycopg2 && \
    python ct_estimator.py
