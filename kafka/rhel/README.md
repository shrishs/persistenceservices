## Kafka imaged based on RHEL

# Build Creation
- Create the follwoing project.This project will contain all the docker build based on RHEL

  oc new-project mov-doc-build --display-name=mov-doc-build --description="docker build for RHEL based images"

- Create a RHEL and java based imagestream.
```
  oc create -f rhel-imagestream.yml
  oc create -f redhat-openjdk-18-is.yaml
```


- Create the build based on Docker file(Docker Strategy) available in the git repository.First time build starts automatically and on
  successfull completion ,it will push the final image to internal repository.

  oc process -f kafka-buildtemplate.yml | oc create -f -

  If it does not start automatically ,One can start it with the following command.

   oc start-build zookeeper --follow

- To delete all the build related artifacts.Execute the following.

```
 oc delete all --selector=application=kafka 
 oc delete is redhat-openjdk-18 rhel 

```


# Statefulset creation

- Create a new project for running the image created in last step. 

  oc new-project zookeeper-rhel --display-name=zookeeper-rhel --description="Zookeper based on the rhel image"

- As the image cretaed in internal registry is stored in different project.Tag it to the new project/namespace.
  
```
  export BUILD_PROJECT_NAME=movi-persistence-poc-builder
  oc tag $BUILD_PROJECT_NAME/kafka:1.0.0 movi-kafka:dev
```


- Create configmap

 oc create configmap broker-config --from-file=init.sh --from-file=mov-config-server.properties

- By default on specifying movi-kafka:dev in statefulset definition,it tries to fetch it from the external repo(dockerhub).To make sure it looks it from internal registry ,execute the following .
 
  oc set image-lookup movi-kafka

- Create the required statefulset and othe related object. 

  oc process -f kafka-apptemplate.yml | oc create -f -

** One can also specify the parameter using -p option

- Please verify if all 3 pods are running.

  oc get pods -w

In order to do some basic testing create the topics and check them if they are created and at the same time check the kafka logs.execute the following.

- check the topic list in order to create a new topics 

oc run cmd-kafka --image solsson/kafka:1.0.0@sha256:17fdf1637426f45c93c65826670542e36b9f3394ede1cb61885c6a4befa8f72d --rm -ti --command -- /opt/kafka/bin/kafka-topics.sh --zookeeper zookeeper:2181 --list

- Create topics and check if it is existing by using list command

oc run cmd-kafka --image solsson/kafka:1.0.0@sha256:17fdf1637426f45c93c65826670542e36b9f3394ede1cb61885c6a4befa8f72d --rm -ti --command -- /opt/kafka/bin/kafka-topics.sh --zookeeper zookeeper:2181 --create --if-not-exists --topic=test-produce-consume --partitions=1 --replication-factor=2

- Check kafka logs ,one can see activities regarding the new topics.

# Scaling up Kafka

oc scale statefulset/kafka --replicas=5

# Scaling down Kafka

oc scale statefulset/kafka --replicas=3

# upgrading base image of Kafka
  
- start the build after chaniging the Dockerfile or some environment variable

oc start-build kafka -n $BUILD_PROJECT_NAME 

-  Make sure build is successfull .Tag the image where statefulset is deployed.

oc tag mov-doc-build/kafka:1.0.0 movi-kafka:dev

An automatic rollout deployment is triggered.

# Quality of Service

Quality of service is Guarateed as request and limit is of the same size.

In case one need to change the request/limit at the runtime ,Execute the following.

oc set resources statefulset/kafka --requests=cpu=256m,memory=512Mi --limits=cpu=256m,memory=512Mi

Make sure KAFKA_HEAP_OPTS  set in kafka statefulset should be less than the memory size set in the above command.For example if KAFKA_HEAP_OPTS is 2G then limit should be 3G.


# Prometheus

- Add the jmx_prometheus_javaagent inside the final image and run the java with this agent as an option.Please check the Dockerfile and env vaariable inside the statefulset for more details.

- Add the following in client facing service

1)Add the following in metadata--annotations-->

```
  annotations:
    prometheus.io/port: '9404'
    prometheus.io/scheme: http
    prometheus.io/scrape: 'true'
```

2)Add the following in spec--ports-->

```
    - name: prometheus
      port: 9404
      protocol: TCP
      targetPort: 9404

```
- Check if the service is visible at prometheus url


# Deleting kafka artifacts.

```
oc delete all --selector=application=kafka
oc delete configmap broker-config
oc delete is movi-kafka
```

