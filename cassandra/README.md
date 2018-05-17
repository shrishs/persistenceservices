# Deploying Cassandra Stateful Set on Openshift

The repository contains source for a RHEL based Cassandra image designed to deploy on Openshift. The image requires a service account that is bound to a Security Context Constraint with IPC_LOCK. The image is designed to run with a SCC having `MustRunAsRange` for user. Openshift will assign the container a UID to execute as within a range assigned by Openshift. The UID belongs to the root group (gid 0). All files must be accessible to the root group (`chgrp 0 <file>`).

Changes to this image have been made from the Google K8s example for deploying Cassandra in a stateful set. Namely, all the files owned by Cassandra are modified to belong to the root group. An explicit RUN command has been added to the Dockerfile to override the JMX authentication. This is mirrored from the current Movilizer practice.

When modifying the image, any new files that are used in execution must be accessible by root group.

## Docker Image Build Creation
*This assumes you have proper access to the cluster*

- Create the follwoing project.This project will contain all the docker build based on RHEL

  oc new-project mov-doc-build --display-name=mov-doc-build --description="docker build for RHEL based images"
- Create a RHEL and java based imagestream.
```
  oc create -f rhel-imagestream.yml
  oc create -f redhat-openjdk-18-is.yaml
```

- Create the build based on Docker file(Docker Strategy) available in the git repository.First time build starts automatically and on successfull completion ,it will push the final image to internal repository.

  oc process -f cassandra-buildtemplate.yaml | oc create -f -
 
 If it does not start automatically ,One can start it with the following command.

   oc start-build cassandra --follow

- To delete all the build related artifacts.Execute the following.

```
 oc delete all --selector=application=cassandra 
 oc delete is redhat-openjdk-18 rhel 
```



## Deploy Cassandra Stateful Set

### Prerequisites
Prior to deploying the stateful set, the following prerequisites must be met.

0. Switch to the project you wish to deploy Cassandra.

    ```bash
    oc project <project name>
    ```

#### Security Context Constraint Configuration

Cassandra requires a service account that has IPC_LOCK capabilities. We must create a service account that has the proper constraint.

*Note: The commands for this section require cluster admin rights.*

0. Export the restricted scc to use as a template.

    ```bash
    oc export scc restricted -o yaml > allow-ipc-scc.yaml
    ```

0. Edit the file to rename to `allow-ipc-lock` add the following lines:

    ```bash
    allowedCapabilities:
    - IPC_LOCK
    ```

0. Create the new constraint.

    ```bash
    oc create -f allow-ipc-scc.yaml
    ```

0. Create the service account.

    ```bash
    oc create sa cassandra-sa
    ```

0. Assign the scc to the service account.

    ```bash
    oc adm policy add-scc-to-user allow-ipc-lock system:serviceaccount:<project name>:cassandra-sa
    ```

#### Image Stream Configuration

0. Tag the `cassandra-rhel` image for usage in your project.

    ```bash
    export BUILD_PROJECT_NAME=movi-persistence-poc-builder
    oc tag $BUILD_PROJECT_NAME/cassandra:latest cassandra-rhel:dev
    ```

    *Note: You can tag the image with whichever tag name you choose, but it must be supplied to the cassandra template for proper image pulling.*

    Use the following command to view the available image streams. You should see one for `cassandra-rhel`. This is the one we will set for image lookup.

    ```bash
    oc get imagestream
    ```

    Now configure the project to use the image stream instead of looking in dockerhub.

    ```bash
    oc set image-lookup cassandra-rhel
    ```

#### Application Property Configuration

0. Create a config map containing configuration options specific to the application using Cassandra.

    The default configuration is provided in the repo at `cassandra-default-config.yaml`.

0. Create the config map object:

    ```bash
    oc create -f cassandra-default-config.yaml
    ```

#### Deploy Cassandra

The repo has a template for deploying the stateful set with a service.

0. Run the following command to see details about the template parameters:

    ```bash
    oc process --parameters -f cassandra-template.yaml
    ```

0. Process the template with the following command, replacing parameter values with ones specific for your app. The namespace parameter is the project that cassandra will be running in:

    ```bash
    export DEPLOY_PROJECT_NAME=movi-persistence-poc

    oc process -f cassandra-template.yaml \
    -p SERVICE_ACCOUNT=cassandra-sa \
    -p NAMESPACE=$DEPLOY_PROJECT_NAME \
    -p CONFIG_MAP_NAME=cassandra-default-config \
    -p IMAGE_TAG_NAME=dev \
    -o yaml
    ```

    *Note: Running this command will allow you to see output of the template without creating any objects. You can redirect the output to a file if you wish.*

0. Alternatively, you can create the Openshift objects directly by piping the output to `oc create`:

    ```bash

    export DEPLOY_PROJECT_NAME=movi-persistence-poc

    oc process -f cassandra-template.yaml \
    -p SERVICE_ACCOUNT=cassandra-sa \
    -p NAMESPACE=$DEPLOY_PROJECT_NAME cassandra-rhel \
    -p CONFIG_MAP_NAME=cassandra-default-config \
    -p IMAGE_TAG_NAME=dev \
    -o yaml \
    | oc create -f -
    ```

0. You should see the service and stateful set have been created. You can view the status with the following:

    ```bash
    oc get statefulset cassandra
    ```

    Alternatively, you can view the stateful set in the web ui. You will see pod deployments for the number of replicas specified in the template with the `REPLICA_COUNT` parameter.

## Details on Cassandra Configuration

The Cassandra image, when built, maintains the default configuration in the cassandra.yaml provided by the Google example stateful set.

The `cassandra-default-config.yaml` contains a config map with the default Cassandra config used by Movilizer. When deploying cassandra with a special config, a new config map should be created and referenced in the processing of the template.


# Prometheus

- Add the jmx_prometheus_javaagent inside the final image and run the java with this agent as an option.Please check the Dockerfile and run.sh for more details.

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

- Check if the service is up at the prometheus url.


# Scaling up cassandra

oc scale statefulset/cassandra --replicas=5

# Scaling down cassandra

oc scale statefulset/cassandra --replicas=3


# upgrading cassandra base image

- start the build after changing the Dockerfile or some environment variable 

oc start-build cassandra -n $BUILD_PROJECT_NAME --follow


- Make sure build is successfull .Tag the image where statefulset is deployed. 

```

oc tag $BUILD_PROJECT_NAME/cassandra:latest cassandra-rhel:dev

Tag cassandra-rhel:dev set to movi-persistence-poc-builder/cassandra@sha256:a0e5f187a1302b956fc0cf247b83aa655fe84d0d5ff3f346813bed941366ec28.

```

An automatic rollout deployment should take place.But at the moment it is not working .A support ticket has been created.Till this problem is resolved ,manual process is as follows.

- get the effective image url of the image used in statefulset as follows.

```
oc get statefulset cassandra -o yaml|grep image:

        image: 10.28.72.220:5000/movi-persistence-poc/cassandra-rhel@sha256:1eed9f8a510cf1acdbe8dd378f865fe4cafa50a15556725b3be2375dde02c045


```
- get the latest @sha256 created  due to tagging.

```
oc get is cassandra-rhel -o custom-columns=IMAGENAME:spec.tags[0].from.name

IMAGENAME
cassandra@sha256:a0e5f187a1302b956fc0cf247b83aa655fe84d0d5ff3f346813bed941366ec28


```
- update the above @sha256 in effective image url and  execute the following command

```
oc set image statefulset/cassandra cassandra=10.28.72.220:5000/movi-persistence-poc/cassandra-rhel@sha256:a0e5f187a1302b956fc0cf247b83aa655fe84d0d5ff3f346813bed941366ec28

```

All the pods of statefulset are upgraded as per the upadteStreategy(RollingUpdate)


# Deleting cassandra  artifacts

- oc delete all --selector=app=cassandra
- oc delete configmap cassandra-default-config
- oc delete is cassandra-rhel


