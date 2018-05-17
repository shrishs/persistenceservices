# Copyright 2017 The Kubernetes Authors.
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

FROM redhat-openjdk-18:latest


#ARG BUILD_DATE
#ARG VCS_REF
#ARG CASSANDRA_VERSION
#ARG DEV_CONTAINER

#LABEL \
#    org.label-schema.build-date=$BUILD_DATE \
#    org.label-schema.docker.dockerfile="/Dockerfile" \
#    org.label-schema.license="Apache License 2.0" \
#    org.label-schema.name="k8s-for-greeks/docker-cassandra-k8s" \
#    org.label-schema.url="https://github.com/k8s-for-greeks/"

ENV CASSANDRA_VERSION=3.0.15 \
    DUMB_INIT_VERSION=1.2.1

ENV DEV_CONTAINER=false \
    DEV_TEST3=false \
    CASSANDRA_HOME=/usr/local/apache-cassandra-${CASSANDRA_VERSION} \
    CASSANDRA_CONF=/etc/cassandra \
    CASSANDRA_DATA=/cassandra_data \
    CASSANDRA_LOGS=/var/log/cassandra \
    PATH=${PATH}:/usr/local/apache-cassandra-${CASSANDRA_VERSION}/bin


USER root

ADD files /

RUN chmod u+x /installPrereqs.sh && \
    /installPrereqs.sh

RUN chmod u+x /installCassandra.sh && \
    /installCassandra.sh


RUN chmod u+x /ready-probe.sh

# JVM_OPTS="$JVM_OPTS -Dcom.sun.management.jmxremote.authenticate=true" to false
# We need to be able to connect to the cluster from cassandra-reaper
# The chgrp is required because the RUN command with sed is reverting the group id.
RUN sed -ri 's/authenticate=true/authenticate=false/' $CASSANDRA_CONF/cassandra-env.sh && \
    chgrp 0 $CASSANDRA_CONF/cassandra-env.sh


RUN mkdir -p /usr/local/prometheus && \
    curl -o /usr/local/prometheus/jmx_prometheus_javaagent.jar https://repo1.maven.org/maven2/io/prometheus/jmx/jmx_prometheus_javaagent/0.1.0/jmx_prometheus_javaagent-0.1.0.jar

COPY files/cassandra-prom.yml /usr/local/prometheus/

USER cassandra

VOLUME ["/$CASSANDRA_DATA"]

# 7000: intra-node communication
# 7001: TLS intra-node communication
# 7199: JMX
# 9042: CQL
# 9160: thrift service
EXPOSE 7000 7001 7199 9042 9160 


ENV DEV_CONTAINER12=false 

CMD ["/usr/local/bin/dumb-init", "/bin/bash", "/run.sh"]
