## Zookeeper imaged based on RHEL

# Build Creation
- Create the follwoing project.This project will contain all the docker build based on RHEL

  oc new-project mov-doc-build --display-name=mov-doc-build --description="docker build for RHEL based images"
- Create a RHEL and java based imagestream.
```
  oc create -f rhel-imagestream.yml
  oc create -f redhat-openjdk-18-is.yaml
```

- Create the build based on Docker file(Docker Strategy) available in the git repository.First time build starts automatically and on successfull completion ,it will push the final image to internal repository.

  oc process -f zookeeper-builtemplate.yml | oc create -f -
 
If it does not start automatically ,One can start it with the following command.

   oc start-build zookeeper --follow

- To delete all the build related artifacts.Execute the following.

```
 oc delete all --selector=application=zookeeper 
 oc delete is redhat-openjdk-18 rhel 
```

# Statefulset creation

- Create a new project for running the image created in last step. 

  oc new-project zookeeper-rhel --display-name=zookeeper-rhel --description="Zookeper based on the rhel image"
- As the image cretaed in internal registry is stored in different project.Tag it to the new project/namespace.

```
  export BUILD_PROJECT_NAME=movi-persistence-poc-builder
  oc tag $BUILD_PROJECT_NAME/zookeeper:3.4.11 movi-zookeeper:dev
```

- By default on specifying movi-zookeeper:dev in statefulset definition,it tries to fetch it from the external repo(dockerhub).To make sure it looks it from internal registry ,execute the following .
 
  oc set image-lookup movi-zookeeper

- Create the required statefulset and other related object. 

  oc process -f zookeeper-apptemplate.yml | oc create -f -
   
 ** One can also specify the parameter using -p option.

Please verify if all 3 pods are running.
 
 oc get pods -w


# scaling up/down zookeeper

- In order to scaleup zookeeper instances ,One need to scale down to 0 .ex:In order to scale the number of replicas from 3 to 5 

scale down to 0

oc scale statefulset/zookeeper --replicas=0

Make sure all the pods are deleted.

oc get pods -w |grep zookeeper

scale up to 5

oc set env statefulset/zookeeper ZK_REPLICAS=5

oc scale statefulset/zookeeper --replicas=5

Same process is applicable for scaling down the number of replicas.

# Quality of Service

Quality of service is Guarateed as request and limit is of the same size.

In case one need to change the request/limit at the runtime ,Execute the following.
 
oc set resources statefulset/zookeeper --requests=cpu=256m,memory=512Mi --limits=cpu=256m,memory=512Mi

Make sure jvm.heap size set in zookeeper-config configmap should be less than the memory size set in the above 
command.For example if jvm.heap is 2G then limit should be 3G.


# Prometheus

- Add the jmx_prometheus_javaagent inside the final image and run the java with this agent as an option.Please check the Dockerfile and zkGenconfig.sh for more details.

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

- Check if the service is up at the following location.

https://prometheus-openshift-metrics.dev.spec.honeywell.com/targets

# upgrading zookeeper base image

- start the build after changing the Dockerfile or some environment variable 

oc start-build kafka -n mov-doc-build

- Make sure build is successfull .Tag the image where statefulset is deployed. 

oc tag mov-doc-build/zookeeper:3.4.11 movi-zookeeper:dev

An automatic rollout deployment is triggered.

# Deleting zookeepr artifacts

- oc delete all --selector=application=zookeeper
- oc delete is movi-zookeeper
- oc delete configmap zookeeper-config


