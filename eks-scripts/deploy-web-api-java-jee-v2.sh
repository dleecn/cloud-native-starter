#!/bin/bash

root_folder=$(cd $(dirname $0); cd ..; pwd)

CFG_FILE=${root_folder}/local.env
# Check if config file exists
if [ ! -f $CFG_FILE ]; then
     _out Config file local.env is missing! Check our instructions!
     exit 1
fi  
source $CFG_FILE

# Login to Amazon Elastic Container Registry
aws ecr get-login-password | docker login --username AWS --password-stdin $REGISTRY

exec 3>&1

function _out() {
  echo "$(date +'%F %H:%M:%S') $@"
}

function setup() {
  _out Deploying web-api-java-jee v2
  
  cd ${root_folder}/web-api-java-jee

  file="${root_folder}/web-api-java-jee/liberty-opentracing-zipkintracer-1.3-sample.zip"
  if [ -f "$file" ]
  then
	  echo "$file found"
  else
	  curl -L -o $file https://github.com/WASdev/sample.opentracing.zipkintracer/releases/download/1.3/liberty-opentracing-zipkintracer-1.3-sample.zip
  fi
  unzip -o liberty-opentracing-zipkintracer-1.3-sample.zip -d liberty-opentracing-zipkintracer/

  # sed 's/5/10/' src/main/java/com/ibm/webapi/business/Service.java > src/main/java/com/ibm/webapi/business/Service2.java
  # rm src/main/java/com/ibm/webapi/business/Service.java
  # mv src/main/java/com/ibm/webapi/business/Service2.java src/main/java/com/ibm/webapi/business/Service.java
  
  # docker build replacement for ECR
  docker build -f Dockerfile.nojava -t $REGISTRY/$REGISTRY_NAMESPACE/web-api:2 .
  docker push $REGISTRY/$REGISTRY_NAMESPACE/web-api:2

  kubectl delete -f deployment/istio-service-v1.yaml --ignore-not-found

  # Add ECR tags to K8s deployment.yaml  
  sed "s+web-api:2+$REGISTRY/$REGISTRY_NAMESPACE/web-api:2+g" deployment/kubernetes-deployment-v2.yaml > deployment/EKS-kubernetes-deployment-v2.yaml
  kubectl apply -f deployment/EKS-kubernetes-deployment-v2.yaml

  kubectl apply -f deployment/istio-service-v2.yaml

  # sed 's/10/5/' src/main/java/com/ibm/webapi/business/Service.java > src/main/java/com/ibm/webapi/business/Service2.java
  # rm src/main/java/com/ibm/webapi/business/Service.java
  # mv src/main/java/com/ibm/webapi/business/Service2.java src/main/java/com/ibm/webapi/business/Service.java

  _out Done deploying web-api-java-jee v2
  _out Wait until the pod has been started. Check with these commands: 
  _out "kubectl get pod --watch | grep web-api"
}

setup
