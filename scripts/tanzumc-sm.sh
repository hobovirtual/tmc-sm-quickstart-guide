#!/bin/bash
if [ $1 = "push-images" ]
then
    /work/tmc-sm push-images harbor --project $IMGPKG_REGISTRY_HOSTNAME/$PROJECT --username $IMGPKG_REGISTRY_USERNAME --password $IMGPKG_REGISTRY_PASSWORD
    echo "copying busybox" && imgpkg copy --tar /work/images/busybox.tar --to-repo $IMGPKG_REGISTRY_HOSTNAME/$PROJECT/busybox --include-non-distributable-layers
    echo "copying openldap" &&  imgpkg copy --tar /work/images/openldap.tar --to-repo $IMGPKG_REGISTRY_HOSTNAME/$PROJECT/openldap --include-non-distributable-layers
    echo "copying dex" &&  imgpkg copy --tar /work/images/dex.tar --to-repo $IMGPKG_REGISTRY_HOSTNAME/$PROJECT/dex --include-non-distributable-layers
elif [ $1 = "tkc" ]
then
    /work/scripts/kubectl-vsphere login --server $SUPERVISOR -u $USERNAME --insecure-skip-tls-verify
    kubectl apply -f tkc/tkc-tmc.yaml
    clustername=`yq .metadata.name tkc/tkc-tmc.yaml`
    namespace=`yq .metadata.namespace tkc/tkc-tmc.yaml`

    while [[ $(kubectl get cluster $clustername -o=jsonpath='{.status.conditions[?(@.type=="Ready")].status}' -n $namespace) != "True" ]]; do
        echo "waiting for cluster to be ready"
        sleep 30
    done
elif [ $1 = "help" ]
then
    echo "help!!!!"
fi