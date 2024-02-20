#!/bin/bash

VERSION=${1:-"v0.56.16"}
LATEST_RELEASE=${2:-"sonobuoy_0.56.16_linux_amd64.tar.gz"}
CUSTOM_REGISTRY=${3:-"myharbor.mydomain.com"}
DOCKER_PROXY=${4:-"harbor.tanzu.io:8443/dockerhub-proxy-cache"} # optional argument
CUSTOM_TMC_REPO="${CUSTOM_REGISTRY}/tmc-install/498533941640.dkr.ecr.us-west-2.amazonaws.com"

# https://kubernetes.io/releases/patch-releases/
k8s_versions=(v1.27.1)

wget "https://github.com/vmware-tanzu/sonobuoy/releases/download/${VERSION}/${LATEST_RELEASE}"
tar -xvf ${LATEST_RELEASE}

for i in "${k8s_versions[@]}"
do
   echo "================CHECKING K8S: $i=======================" 
   ./sonobuoy images list --kubernetes-version $i > images_$i.txt

   while read image
   do
   echo "================CHECKING IMAGE: $image=================="
   base=$(basename "$image")
   output=${image#*/*}

   if [[ $image == *"docker"* && -n $DOCKER_PROXY ]];
   then
       docker pull $DOCKER_PROXY/$output
       docker tag $DOCKER_PROXY/$output ${CUSTOM_TMC_REPO}/extensions/inspection-images/$base
   else
       docker pull $image
       docker tag $image ${CUSTOM_TMC_REPO}/extensions/inspection-images/$base
   fi

   docker push ${CUSTOM_TMC_REPO}/extensions/inspection-images/$base
   echo "===================PUSHING: ${CUSTOM_TMC_REPO}/extensions/inspection-images/$base ==========="
   done < images_$i.txt
done

# not part of sonobuoy image list, install manually, update these as images are found
docker pull k8s.gcr.io/e2e-test-images/agnhost:2.31
docker pull k8s.gcr.io/pause:3.9
docker pull registry.k8s.io/e2e-test-images/volume/gluster:1.3
docker pull registry.k8s.io/e2e-test-images/volume/nfs:1.3
docker tag registry.k8s.io/e2e-test-images/volume/gluster:1.3 ${CUSTOM_TMC_REPO}/extensions/inspection-images/volume/gluster:1.3
docker tag registry.k8s.io/e2e-test-images/volume/nfs:1.3 ${CUSTOM_TMC_REPO}/extensions/inspection-images/volume/nfs:1.3
docker tag k8s.gcr.io/e2e-test-images/agnhost:2.31 ${CUSTOM_TMC_REPO}/extensions/inspection-images/agnhost:2.31
docker tag k8s.gcr.io/pause:3.9 ${CUSTOM_TMC_REPO}/extensions/inspection-images/pause:3.9
docker push ${CUSTOM_TMC_REPO}/extensions/inspection-images/agnhost:2.31
docker push ${CUSTOM_TMC_REPO}/extensions/inspection-images/pause:3.9
docker push ${CUSTOM_TMC_REPO}/extensions/inspection-images/volume/gluster:1.3
docker push ${CUSTOM_TMC_REPO}/extensions/inspection-images/volume/nfs:1.3

# clean up text files and sonobuoy tar
rm images_*
rm sonobuoy_*
