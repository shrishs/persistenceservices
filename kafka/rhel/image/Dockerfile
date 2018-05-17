FROM redhat-openjdk-18:latest


ENV JAVA_HOME=/usr/lib/jvm/java-1.8.0 \
    KAFKA_HOME=/opt/kafka 

COPY fix-permissions /usr/local/bin

USER root

RUN INSTALL_PKGS="gettext tar zip unzip hostname " && \
    yum install -y $INSTALL_PKGS && \
    rpm -V $INSTALL_PKGS && \
    yum clean all  && \
    mkdir -p $KAFKA_HOME && \
    curl -fsSL https://archive.apache.org/dist/kafka/${KAFKA_VERSION}/kafka_${SCALA_VERSION}-${KAFKA_VERSION}.tgz | tar xzf - --strip 1 -C $KAFKA_HOME/ && \
    mkdir -p $KAFKA_HOME/logs && \
    /usr/local/bin/fix-permissions $KAFKA_HOME 


RUN mkdir -p /opt/kafka/prometheus && \
    curl -o /opt/kafka/prometheus/jmx_prometheus_javaagent.jar https://repo1.maven.org/maven2/io/prometheus/jmx/jmx_prometheus_javaagent/0.1.0/jmx_prometheus_javaagent-0.1.0.jar


COPY kafka.yaml /opt/kafka/prometheus/


WORKDIR "/opt/kafka"

EXPOSE 9092
