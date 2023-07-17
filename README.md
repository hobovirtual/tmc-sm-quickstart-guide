# tanzu mission control - self managed - tkg

Configuration and instructions for installing tmc sm on tkg, a lot of this content was taking from various contributors.
Please note this setup is using unsupported configuration

## prerequisite
- tkc 1.23+
- cert-manager 0.11+
- kapp controller
- carvel tools installed (ytt)
- kubectl cli
- (optional) external-dns for dynamic dns configuration
- harbor project with the tmc-sm containers see the [Download and stage the installation images section](https://docs.vmware.com/en/VMware-Tanzu-Mission-Control/1.0/tanzumc-sm-install/install-tmc-sm.html)
- a registry (can be the same harbor project) with busybox and openldap container image


Please review TMC Self Managed requirements [here](https://docs.vmware.com/en/VMware-Tanzu-Mission-Control/1.0/tanzumc-sm-install/prepare-cluster.html)

## installation steps

### clone this repo

### copy busybox - openldap - dex to your registry
```
# busybox
-- imgpkg copy --tar images/busybox.tar --to-repo myharbor.mydomain.com/myproject/dex --include-non-distributable-layer

# openldap
-- imgpkg copy --tar images/openldap.tar --to-repo myharbor.mydomain.com/myproject/dex --include-non-distributable-layer

# dex
-- imgpkg copy --tar images/dex.tar --to-repo myharbor.mydomain.com/myproject/dex --include-non-distributable-layer
```

### login to tanzu kubernetes clussupervisor
```
kubectl vsphere login --server [supervisor ip|fqdn] -u [username] #(optional) --insecure-skip-tls-verify
```

### modify the tkc/tkc-tmc.yaml file with your values

### create the tanzu kubernetes cluster
```
kubectl apply -f tkc/tkc-tmc.yaml

export clustername=`yq .metadata.name tkc/tkc-tmc.yaml`
export namespace=`yq .metadata.namespace tkc/tkc-tmc.yaml`

while [[ $(kubectl get cluster $clustername -o=jsonpath='{.status.conditions[?(@.type=="Ready")].status}' -n $namespace) != "True" ]]; do
    echo "waiting for cluster to be ready"
    sleep 30
done
```

### login to tanzu kubernetes cluster
```
kubectl vsphere login --server [supervisor ip|fqdn] -u [username] --tanzu-kubernetes-cluster-namespace $namespace --tanzu-kubernetes-cluster-name $clustername #(optional) --insecure-skip-tls-verify
```

### switch context and create cluster role
```
kubectl config set-context $clusternam
kubectl apply -f config/clusterrolebinding.yaml
```

### install kapp (only if not present) - as documented here

### install tanzu packages (cert-manager and external-dns)

```
kubectl apply -f packages/standard/ns.yaml
kubectl apply -f packages/standard/sa.yaml
ytt -f config/common-values.yaml -f packages/standard/secrets.yaml | kubectl apply -f -

# kapp-controller (trust harbor)
kubectl -n tkg-system delete po -l app=kapp-controller

# package repository
ytt -f config/common-values.yaml -f packages/standard/pkgr.yaml | kubectl apply -f -

export name=`yq .metadata.name packages/standard/pkgr.yaml`
export namespace=`yq .metadata.namespace packages/standard/pkgr.yaml`

while [[ $(kubectl -n $namespace get pkgr $name -o=jsonpath='{.status.conditions[?(@.type=="ReconcileSucceeded")].status}') != "True" ]]; do
    echo "waiting for repository $name to be ready"
    sleep 10
done

# package install
ytt -f config/common-values.yaml -f packages/standard/pkgi.yaml | kubectl apply -f -

while [[ $(kubectl -n $namespace get pkgi cert-manager -o=jsonpath='{.status.conditions[?(@.type=="ReconcileSucceeded")].status}') != "True" ]]; do
    echo "waiting for cert-manager to be ready"
    sleep 10
done

while [[ $(kubectl -n $namespace get pkgi external-dns -o=jsonpath='{.status.conditions[?(@.type=="ReconcileSucceeded")].status}') != "True" ]]; do
    echo "waiting for external-dns to be ready"
    sleep 10
done
```

### configure tanzu mission control self-managed
```
kubectl apply -f packages/tmc/ns.yaml
kubectl apply -f packages/tmc/sa.yaml

# certificate cluster issuer
ytt -f config/common-values.yaml -f config/localissuer.yaml | kubectl apply -f -

# package repository
ytt -f config/common-values.yaml -f packages/tmc/pkgr.yaml | kubectl apply -f -

export name=`yq .metadata.name packages/tmc/pkgr.yaml`
export namespace=`yq .metadata.namespace packages/tmc/pkgr.yaml`

while [[ $(kubectl -n $namespace get pkgr $name -o=jsonpath='{.status.conditions[?(@.type=="ReconcileSucceeded")].status}') != "True" ]]; do
    echo "waiting for repository $name to be ready"
    sleep 10
done

# package install
ytt -f config/common-values.yaml -f packages/tmc/secrets.yaml -f packages/tmc/pkgi.yaml | kubectl apply -f -

while [[ $(kubectl -n $namespace get pkgi contour -o=jsonpath='{.status.conditions[?(@.type=="ReconcileSucceeded")].status}') != "True" ]]; do
    echo "waiting for contour to be ready"
    sleep 10
done

# install dex (OIDC)
ytt -f config/common-values.yaml -f packages/dex/deployment.yaml| kubectl apply -f -
kubectl annotate packageinstalls tmc -n tmc-local ext.packaging.carvel.dev/ytt-paths-from-secret-name.2=tmc-overlay-override-dex
kubectl patch -n tmc-local --type merge pkgi tmc --patch '{"spec": {"paused": true}}'
kubectl patch -n tmc-local --type merge pkgi tmc --patch '{"spec": {"paused": false}}'
 
# openldap
ytt -f config/common-values.yaml -f packages/openldap/deployment.yaml | kubectl apply -f -
```