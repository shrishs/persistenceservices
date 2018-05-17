#!/bin/bash

# Copyright 2018 The Kubernetes Authors.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

umask 002

#download cassandra
CASSANDRA_PATH="cassandra/${CASSANDRA_VERSION}/apache-cassandra-${CASSANDRA_VERSION}-bin.tar.gz"
CASSANDRA_DOWNLOAD="http://www.apache.org/dyn/closer.cgi?path=/${CASSANDRA_PATH}&as_json=1"
CASSANDRA_MIRROR=`wget -q -O - ${CASSANDRA_DOWNLOAD} | grep -oP "(?<=\"preferred\": \")[^\"]+"`

echo "Downloading Apache Cassandra from $CASSANDRA_MIRROR$CASSANDRA_PATH..."
wget -q -O /tmp/apache-cassandra-bin.tar.gz $CASSANDRA_MIRROR$CASSANDRA_PATH

#verify apache cassandra checksum
wget -O /tmp/apache-cassandra-md5sum https://www-us.apache.org/dist/cassandra/$CASSANDRA_VERSION/apache-cassandra-$CASSANDRA_VERSION-bin.tar.gz.md5

CASSANDRA_CHECKSUM=$(cat /tmp/apache-cassandra-md5sum)
CASSANDRA_HASH=$(md5sum /tmp/apache-cassandra-bin.tar.gz | cut -c 1-32)

if [[ $CASSANDRA_CHECKSUM == $CASSANDRA_HASH ]]; then
  echo "Valid checksum for apache cassandra download"
else
  echo "Invalid checksum for apache cassandra download"
  echo "download hash: $CASSANDRA_HASH"
  echo "checksum: $CASSANDRA_CHECKSUM"
  exit 1
fi

#unpack tar file
echo "unpacking install tarball"
tar -xzf /tmp/apache-cassandra-bin.tar.gz -C /usr/local --delay-directory-restore

#cleanup
rm -f /tmp/apache-cassandra-md5sum /tmp/apache-cassandra-bin.tar.gz
unset CASSANDRA_CHECKSUM CASSANDRA_HASH

adduser --no-create-home cassandra

mkdir -p $CASSANDRA_DATA/data
mkdir -p $CASSANDRA_CONF
mkdir -p $CASSANDRA_LOGS

echo "organizing cassandra configuration"
mv /logback.xml /cassandra.yaml /jvm.options $CASSANDRA_CONF
mv /usr/local/apache-cassandra-${CASSANDRA_VERSION}/conf/cassandra-env.sh $CASSANDRA_CONF

chmod g+x /ready-probe.sh
chmod g+x $CASSANDRA_CONF/cassandra-env.sh
chown cassandra:0 /ready-probe.sh

chmod 664 $CASSANDRA_CONF/*
chown -R cassandra:0 $CASSANDRA_HOME $CASSANDRA_CONF $CASSANDRA_DATA $CASSANDRA_LOGS

DEV_IMAGE=${DEV_CONTAINER:-}
if [ ! -z "$DEV_IMAGE" ]; then
    yum -y install python;
else
    rm -rf  $CASSANDRA_HOME/pylib;
fi
