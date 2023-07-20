#!/bin/bash
if [ $1 = "push-images" ]
then
    /work/tmc-sm push-images harbor --project $IMGPKG_REGISTRY_HOSTNAME/$PROJECT --username $IMGPKG_REGISTRY_USERNAME --password $IMGPKG_REGISTRY_PASSWORD
    echo "copying busybox" && imgpkg copy --tar /work/images/busybox.tar --to-repo $IMGPKG_REGISTRY_HOSTNAME/$PROJECT/busybox --include-non-distributable-layers
    echo "copying openldap" &&  imgpkg copy --tar /work/images/openldap.tar --to-repo $IMGPKG_REGISTRY_HOSTNAME/$PROJECT/openldap --include-non-distributable-layers
    echo "copying dex" &&  imgpkg copy --tar /work/images/dex.tar --to-repo $IMGPKG_REGISTRY_HOSTNAME/$PROJECT/dex --include-non-distributable-layers

elif [ $1 = "tkc" ]
then
    clustername=`yq eval .metadata.name /work/tkc/tkc-tmc.yaml`
    namespace=`yq eval .metadata.namespace /work/tkc/tkc-tmc.yaml`

    /work/scripts/kubectl-vsphere login --server $SUPERVISOR -u $USERNAME --insecure-skip-tls-verify
    kubectl apply -f /work/tkc/tkc-tmc.yaml
    
    kubectl get cluster $clustername -o=jsonpath='{.status.conditions[?(@.type=="Ready")].status}' -n $namespace

    while [[ $(kubectl get cluster $clustername -o=jsonpath='{.status.conditions[?(@.type=="Ready")].status}' -n $namespace) != "True" ]]; do
        echo "waiting for cluster to be ready"
        sleep 30
    done

elif [ $1 = "tanzu-packages" ]
then
    clustername=`yq eval .metadata.name tkc/tkc-tmc.yaml`
    namespace=`yq eval .metadata.namespace tkc/tkc-tmc.yaml`

    /work/scripts/kubectl-vsphere login --server $SUPERVISOR -u $USERNAME --tanzu-kubernetes-cluster-namespace $namespace --tanzu-kubernetes-cluster-name $clustername --insecure-skip-tls-verify
    kubectl config set-context $clustername
    kubectl apply -f /work/config/clusterrolebinding.yaml    
    
    kubectl apply -f /work/packages/standard/ns.yaml
    kubectl apply -f /work/packages/standard/sa.yaml
    ytt -f /work/config/common-values.yaml -f /work/packages/standard/secrets.yaml | kubectl apply -f -

    # kapp-controller (trust harbor)
    kubectl -n tkg-system delete po -l app=kapp-controller

    # package repository
    ytt -f /work/config/common-values.yaml -f /work/packages/standard/pkgr.yaml | kubectl apply -f -

    export name=`yq eval .metadata.name /work/packages/standard/pkgr.yaml`
    export namespace=`yq eval .metadata.namespace /work/packages/standard/pkgr.yaml`

    while [[ $(kubectl -n $namespace get pkgr $name -o=jsonpath='{.status.conditions[?(@.type=="ReconcileSucceeded")].status}') != "True" ]]; do
        echo "waiting for repository $name to be ready"
        sleep 10
    done

    # package install
    ytt -f /work/config/common-values.yaml -f /work/packages/standard/pkgi.yaml | kubectl apply -f -

    while [[ $(kubectl -n $namespace get pkgi cert-manager -o=jsonpath='{.status.conditions[?(@.type=="ReconcileSucceeded")].status}') != "True" ]]; do
        echo "waiting for cert-manager to be ready"
        sleep 10
    done

    while [[ $(kubectl -n $namespace get pkgi external-dns -o=jsonpath='{.status.conditions[?(@.type=="ReconcileSucceeded")].status}') != "True" ]]; do
        echo "waiting for external-dns to be ready"
        sleep 10
    done

elif [ $1 = "tmc-install" ]
then
    clustername=`yq eval .metadata.name /work/tkc/tkc-tmc.yaml`
    namespace=`yq eval .metadata.namespace /work/tkc/tkc-tmc.yaml`

    /work/scripts/kubectl-vsphere login --server $SUPERVISOR -u $USERNAME --tanzu-kubernetes-cluster-namespace $namespace --tanzu-kubernetes-cluster-name $clustername --insecure-skip-tls-verify
    kubectl config set-context $clustername

    kubectl apply -f /work/packages/tmc/ns.yaml
    kubectl apply -f /work/packages/tmc/sa.yaml

    # certificate cluster issuer
    ytt -f /work/config/common-values.yaml -f /work/config/localissuer.yaml | kubectl apply -f -

    # package repository
    ytt -f /work/config/common-values.yaml -f /work/packages/tmc/pkgr.yaml | kubectl apply -f -

    export name=`yq eval .metadata.name /work/packages/tmc/pkgr.yaml`
    export namespace=`yq eval .metadata.namespace /work/packages/tmc/pkgr.yaml`

    while [[ $(kubectl -n $namespace get pkgr $name -o=jsonpath='{.status.conditions[?(@.type=="ReconcileSucceeded")].status}') != "True" ]]; do
        echo "waiting for repository $name to be ready"
        sleep 10
    done

    # package install
    ytt -f /work/config/common-values.yaml -f /work/packages/tmc/secrets.yaml -f packages/tmc/pkgi.yaml | kubectl apply -f -

    while [[ $(kubectl -n $namespace get pkgi contour -o=jsonpath='{.status.conditions[?(@.type=="ReconcileSucceeded")].status}') != "True" ]]; do
        echo "waiting for contour to be ready"
        sleep 10
    done

    # install dex (OIDC)
    ytt -f /work/config/common-values.yaml -f /work/packages/dex/deployment.yaml| kubectl apply -f -
    kubectl annotate packageinstalls tmc -n tmc-local ext.packaging.carvel.dev/ytt-paths-from-secret-name.2=tmc-overlay-override-dex
    kubectl patch -n tmc-local --type merge pkgi tmc --patch '{"spec": {"paused": true}}'
    kubectl patch -n tmc-local --type merge pkgi tmc --patch '{"spec": {"paused": false}}'
    
    # openldap
    ytt -f /work/config/common-values.yaml -f /work/packages/openldap/deployment.yaml | kubectl apply -f -

    while [[ $(kubectl -n $namespace get pkgi tmc -o=jsonpath='{.status.conditions[?(@.type=="ReconcileSucceeded")].status}') != "True" ]]; do
        echo "waiting for tmc to be ready"
        sleep 30
    done

elif [ $1 = "help" ]
then
    echo "help!!!!"
fi