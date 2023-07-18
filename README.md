# tanzu mission control - self managed - tkg
Hopefully by now you've all heard about Tanzu Mission Control (aka TMC), VMware Tanzu Mission Control is a centralized hub for simplified, multi-cloud, multi-cluster Kubernetes management. More information can be found [here](https://tanzu.vmware.com/mission-control)

Since it's released, Tanzu Mission Control was only available as a VMware Cloud Service, in other words SaaS only. Recently we release an alternative deployment option for Tanzu Mission Control, which is called Self Managed. With this new deployment option, customers who weren't able to use our VMware Cloud Service can benefit from the management capabilities that Tanzu Mission Control offers.

If you want to read more about Tanzu Mission Control Self Managed, you can read our (release blog)[https://tanzu.vmware.com/content/blog/vmware-tanzu-mission-control-self-managed-announcement]

If you're looking to install Tanzu Mission Control Self Managed, please review the list of requirements [here](https://docs.vmware.com/en/VMware-Tanzu-Mission-Control/1.0/tanzumc-sm-install/prepare-cluster.html)

But what if you're just looking for a quick and easy installation to test Tanzu Mission Control Self Managed in your lab/test environment? Well we got you covered, this quickstart guide will guide you with minimal set of requirements. 

Please note that for Production installation you will need to use the [official documentation](https://docs.vmware.com/en/VMware-Tanzu-Mission-Control/1.0/tanzumc-sm-install/index-sm-install.html)

# Quickstart Introduction
This guide was tested on Tanzu Kubernetes Grid on vSphere.

Please note: a lot of the configuration and instructions in this guide was inspired from various contributors at VMware.

Remember, please note this setup is using unsupported configuration

## prerequisite
- a vSphere cluster with Tanzu Workload Management enabled
- a linux bootstrap machine with
    - carvel tools [installed](https://carvel.dev/)
    - kubectl cli installed
    - yq
    - docker desktop
- harbor projects
    1. project with the tmc-sm containers see the [Download and stage the installation images section](https://docs.vmware.com/en/VMware-Tanzu-Mission-Control/1.0/tanzumc-sm-install/install-tmc-sm.html)
    2. project with the tanzu packages [see documentation](https://docs.vmware.com/en/VMware-Tanzu-Kubernetes-Grid/1.6/vmware-tanzu-kubernetes-grid-16/GUID-mgmt-clusters-image-copy-airgapped.html) - or you can use the public repo projects.registry.vmware.com/tkg/packages/standard/repo
    3. project for hosting other containers such as busybox and openldap containers (can be the same harbor project)

## this guide will deploy
- tanzu kubernetes cluster 1.23+
- cert-manager 0.11+
- kapp controller
- external-dns for dynamic dns configuration
    - this is optional but recommended, if you don't want to use dynamic dns configuration you can create two dns entries manually
        - tmc.mydomain.com
        - *.tmc.mydomain.com

# installation steps

## clone this repo
```
git clone https://github.com/hobovirtual/tmc-sm-quickstart-guide.git
cd tmc-sm-quickstart-guide
```
## copy busybox - openldap - dex to your registry
```
export myharbor=myharbor.mydomain.com
export myproject=myproject

# busybox
imgpkg copy --tar images/busybox.tar --to-repo $myharbor/$myproject/busybox --include-non-distributable-layers

# openldap
imgpkg copy --tar images/openldap.tar --to-repo $myharbor/$myproject/openldap --include-non-distributable-layers

# dex
imgpkg copy --tar images/dex.tar --to-repo $myharbor/$myproject/dex --include-non-distributable-layers
```

## Before starting, please make sure you have pushed the Tanzu Mission Control Self Managed containers to your Harbor Registry 
see prerequisite section above

## login to tanzu kubernetes supervisor
```
kubectl vsphere login --server [supervisor ip|fqdn] -u [username] #(optional) --insecure-skip-tls-verify
```

## edit the tkc/tkc-tmc.yaml file with your values
Review and replace all values in {{}} and update with your own

## create the tanzu kubernetes cluster
```
kubectl apply -f tkc/tkc-tmc.yaml

export clustername=`yq .metadata.name tkc/tkc-tmc.yaml`
export namespace=`yq .metadata.namespace tkc/tkc-tmc.yaml`

while [[ $(kubectl get cluster $clustername -o=jsonpath='{.status.conditions[?(@.type=="Ready")].status}' -n $namespace) != "True" ]]; do
    echo "waiting for cluster to be ready"
    sleep 30
done
```

## login to tanzu kubernetes cluster
```
kubectl vsphere login --server [supervisor ip|fqdn] -u [username] --tanzu-kubernetes-cluster-namespace $namespace --tanzu-kubernetes-cluster-name $clustername #(optional) --insecure-skip-tls-verify
```

## switch context and create cluster role
```
kubectl config set-context $clustername
kubectl apply -f config/clusterrolebinding.yaml
```

## validate kapp controller
All recent Tanzu Kubernetes releases should have kapp-controller installed, if not then please install it by following this [guide](https://docs.vmware.com/en/VMware-Tanzu-Kubernetes-Grid/1.6/vmware-tanzu-kubernetes-grid-16/GUID-packages-prep-tkgs-kapp.html)

If you want to validate if it is present in your current Tanzu Kubernetes release
```
kubectl -n tkg-system get po -l app=kapp-controller
```

## edit the config/common-values.yaml file with your values
Review and replace all values in {{}} and update with your own

## install tanzu packages (cert-manager and external-dns)

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

## configure tanzu mission control self-managed
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