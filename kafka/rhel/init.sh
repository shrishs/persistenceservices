#!/bin/bash
set -x

KAFKA_BROKER_ID=${HOSTNAME##*-}
echo $KAFKA_BROKER_ID

cp /config/mov-config-server.properties /opt/kafka/config/mov-config-server.properties

sed -i "s/#init#broker.id=#init#/broker.id=$KAFKA_BROKER_ID/" /opt/kafka/config/mov-config-server.properties


/opt/kafka/bin/kafka-server-start.sh /opt/kafka/config/mov-config-server.properties --override zookeeper.connect=$ZOOKEEPER_HOST --override advertised.host.name=$KAFKA_ADVERTISED_HOST_NAME --override broker.id=$(hostname | awk -F'-' '{print $2}') --override log.dirs=/opt/kafka/data/topics

