# Tanzu Mission Control - Self Managed Quickstart

This is for testing and evaluation purposes only. This QuickStart guide is intended to install Tanzu Mission Control with minimal requirements. For production use cases, please refer to the official [documentation](https://docs.vmware.com/en/VMware-Tanzu-Mission-Control/1.0/tanzumc-sm-install/index-sm-install.html)

Tanzu Mission Control (aka TMC), is a centralized hub for simplified, multi-cloud, multi-cluster Kubernetes management. More information can be found [here](https://tanzu.vmware.com/mission-control)

Tanzu Mission Control has been available to operators as a SaaS offering but is now a deployable application to supported Kubernetes clusters called Tanzu Mission Control Self Managed. This enables customers to utilize the fleet-wide management capabilities of Tanzu Mission Control in organizations where SaaS services are restricted, organizations that need complete application control, or air-gapped environments.

Read more about Tanzu Mission Control Self Managed in this [release blog](https://tanzu.vmware.com/content/blog/vmware-tanzu-mission-control-self-managed-announcement)

# Quickstart Introduction
But what if you're just looking for a quick and easy way to test Tanzu Mission Control Self Managed in your lab/test environment? 

Well we got you covered, this quickstart guide will guide you through the installation with minimal set of requirements.

## Prerequisite
- vSphere with Tanzu enabled on a vSphere cluster
    - with kapp-controller
- A linux bootstrap machine with
    - carvel tools [installed](https://carvel.dev/)
    - kubectl cli installed
    - yq [installed](https://github.com/mikefarah/yq/#install)
    - docker desktop
    - Tanzu Mission Control - Self Managed installer available from the [Customer Connect download site](https://customerconnect.vmware.com/en/downloads/info/slug/infrastructure_operations_management/vmware_tanzu_mission_control_self_managed/1_0_0)
- A network accessible Harbor Registry
    - you need at least one public project for Tanzu Mission Control Self Managed images
    - access to tanzu packages repository - you can use the public repo projects.registry.vmware.com/tkg/packages/standard/repo
        - if you're working with an internet restricted environment, please [see documentation](https://docs.vmware.com/en/VMware-Tanzu-Kubernetes-Grid/1.6/vmware-tanzu-kubernetes-grid-16/GUID-mgmt-clusters-image-copy-airgapped.html)

## In this guide we will deploy the following components
- tanzu kubernetes cluster 1.23+
- cert-manager 0.11+
    - clusterissuer using a self signed certificate (included)
- external-dns for dynamic dns configuration
    - this is optional but recommended, if you don't want to use dynamic dns configuration you can create two dns entries manually
        - tmc.mydomain.com
        - *.tmc.mydomain.com
    - the values provided in this guide are for configuring external-dns with a BIND server, if you're planning to use other or if you want more configuration option, please refer to this [docs](https://docs.vmware.com/en/VMware-Tanzu-Kubernetes-Grid/1.6/vmware-tanzu-kubernetes-grid-16/GUID-packages-external-dns.html#prepare-the-configuration-file-for-the-externaldns-package-3)
- dex (OIDC provider)
- opendlap (for user authentication)

# installation steps

## 1 - clone this repo
```
git clone https://github.com/hobovirtual/tmc-sm-quickstart-guide.git
cd tmc-sm-quickstart-guide
```
## 2 - push images to your harbor registry
### 2.1. prepare bootstrap machine - for more information you can read the [official documentation](https://docs.vmware.com/en/VMware-Tanzu-Mission-Control/1.0/tanzumc-sm-install/install-tmc-sm.html#download-and-stage-the-installation-images-0)
```
mkdir tanzumc
tar -xf tmc-self-managed-1.0.0.tar -C ./tanzumc

export myharbor={{myharbor.mydomain.com}}
export myproject={{myproject}}
```

You also need to add the root CA certificate of Harbor to the /etc/ssl/certs path of the jumpbox for system-wide use. This enables the image push to the Harbor repository in next step.

### 2.2. push tmc images to harbor
```
tanzumc/tmc-sm push-images harbor --project $myharbor/$myproject --username {{username}} --password {{password}}  
```

### 2.3. push images required for dex + openldap to harbor
```
imgpkg copy --tar images/busybox.tar --to-repo $myharbor/$myproject/busybox --include-non-distributable-layers
imgpkg copy --tar images/openldap.tar --to-repo $myharbor/$myproject/openldap --include-non-distributable-layers
imgpkg copy --tar images/dex.tar --to-repo $myharbor/$myproject/dex --include-non-distributable-layers
```

## 3 - login to tanzu kubernetes supervisor
```
kubectl vsphere login --server {{supervisor ip|fqdn}} -u {{username}} #(optional) --insecure-skip-tls-verify
```

## 4 - edit the tkc/tkc-tmc.yaml file with your values
Review and replace all values in {{}} and update with your own

| template value | example value |
| -------------- | ---------- |
| {{vsphere namespace}} | vns-sanbox |
| {{storageclass}} | vsan-default-storage-policy |

## 5 - create the tanzu kubernetes cluster
```
kubectl apply -f tkc/tkc-tmc.yaml

export clustername=`yq .metadata.name tkc/tkc-tmc.yaml`
export namespace=`yq .metadata.namespace tkc/tkc-tmc.yaml`

while [[ $(kubectl get cluster $clustername -o=jsonpath='{.status.conditions[?(@.type=="Ready")].status}' -n $namespace) != "True" ]]; do
    echo "waiting for cluster to be ready"
    sleep 30
done
```

## 6 - login to tanzu kubernetes cluster
```
kubectl vsphere login --server {{supervisor ip|fqdn}} -u {{username}} --tanzu-kubernetes-cluster-namespace $namespace --tanzu-kubernetes-cluster-name $clustername #(optional) --insecure-skip-tls-verify
```

## 7 - switch context and create cluster role
```
kubectl config set-context $clustername
kubectl apply -f config/clusterrolebinding.yaml
```

## 8 - validate that kapp controller is available
Recent Tanzu Kubernetes releases should have kapp-controller installed, if you're using an older release, then please install it by following the [official documentation](https://docs.vmware.com/en/VMware-Tanzu-Kubernetes-Grid/1.6/vmware-tanzu-kubernetes-grid-16/GUID-packages-prep-tkgs-kapp.html)

If you want to validate if kapp-controller is present in your tanzu kubernetes cluster
```
kubectl -n tkg-system get po -l app=kapp-controller
```

## 9 - edit configuration files and update them with your values
Review and replace all values in {{}} and update with your own
### config/common-values.yaml

| template value | example value |
| -------------- | ---------- |
| {{myharbor.mydomain.com}} | harbor.tanzu.lab |
| {{myproject}} | tmc |
| {{mydomain.com}} | tmc.tanzu.lab |
| {{ -----BEGIN CERTIFICATE----- -----END CERTIFICATE-----}} | your harbor certificate |

### packages/standard/secrets.yaml (external-dns)

| template value | example value |
| -------------- | ---------- |
| {{owner id}} | tmc.tanzu.lab |
| {{dns1, dns2}} | 192.168.2.1,192.168.1.1 |
| {{dns zone}} | tanzu.lab |
| {{domain filter}} | tanzu.lab |

*NOTE: If you don't want to use external-dns, you can either remove the section from the secrets.yaml and pkgi.yaml files or leave the default*

## 10 - install tanzu packages (cert-manager and external-dns)

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

## 11 - configure tanzu mission control self-managed
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

## 12 - add the custom cert to your supervisor tkgserviceconfiguration
In order for your workload clusters to trust your Tanzu Mission Control Self Managed instance, you will need to add the custom certificate in the trusted section of your TkgServiceConfiguration, please see [documentation](https://docs.vmware.com/en/VMware-vSphere/7.0/vmware-vsphere-with-tanzu/GUID-059EF257-31AF-4DD2-B475-297C5BCB5F49.html) for more information and instructions

## What's next??
Tanzu Mission Control Self Managed has now been successfully deployed! Access the interface by following using the credentials below.

tmc.{{mydomain.com}}

user  | password
----- |---------
tanzu | VMware1!

To ensure new Tanzu Kubernetes Grid clusters can be managed by Tanzu Mission Control, a custom certificate must be added to the trusted section of your [TkgServiceConfiguration in vSphere with Tanzu](https://docs.vmware.com/en/VMware-vSphere/7.0/vmware-vsphere-with-tanzu/GUID-4838C85E-398D-4461-9C4E-561FADD42A07.html#external-private-registry-configuration-5). 

Follow the documentation to add cert to the additionalTrustedCAs section and add the following lines under the spec section (please note that if you're using your own certificate you will need to modify the data value)

```
spec:
  trust:
    additionalTrustedCAs:
    - name: tmc-sm
      data: LS0tLS1CRUdJTiBDRVJUSUZJQ0FURS0tLS0tCk1JSUYxekNDQTcrZ0F3SUJBZ0lVUktsNVFacFB0amVDRHRWZlVDWjFPcUNYcXFvd0RRWUpLb1pJaHZjTkFRRUwKQlFBd2dZUXhDekFKQmdOVkJBWVRBbFJTTVJFd0R3WURWUVFJREFoSmMzUmhibUoxYkRFUk1BOEdBMVVFQnd3SQpTWE4wWVc1aWRXd3hGekFWQmdOVkJBb01Ea04xYzNSdmJXVnlMQ0JKYm1NdU1Rc3dDUVlEVlFRTERBSkpWREVwCk1DY0dBMVVFQXd3Z0tpNTBiV011YURKdkxUUXRNVEl3TWpJdWFESnZMblp0ZDJGeVpTNWpiMjB3SGhjTk1qTXcKTmpJd01UQXpPRFEwV2hjTk1qWXdOREE1TVRBek9EUTBXakNCaERFTE1Ba0dBMVVFQmhNQ1ZGSXhFVEFQQmdOVgpCQWdNQ0VsemRHRnVZblZzTVJFd0R3WURWUVFIREFoSmMzUmhibUoxYkRFWE1CVUdBMVVFQ2d3T1EzVnpkRzl0ClpYSXNJRWx1WXk0eEN6QUpCZ05WQkFzTUFrbFVNU2t3SndZRFZRUUREQ0FxTG5SdFl5NW9NbTh0TkMweE1qQXkKTWk1b01tOHVkbTEzWVhKbExtTnZiVENDQWlJd0RRWUpLb1pJaHZjTkFRRUJCUUFEZ2dJUEFEQ0NBZ29DZ2dJQgpBTVZVSzE4dXRKMk91U202Uy9WMDBJQXpiM0swTWhQUFNybEtkdlN2b3lRMzN6cHRVSjg2azBYYWhpNWNmaGtpCmZKdkNkbXJiVEpieGRBWnVyMFpCcXNTeDlnMkx6dkdocGJ6RElpM3dUMnd1NHd3bDZ4QzltbzRPTjI0aDdkVkEKbnc5Vm9jOUNDMDBWWWIxYWRlOTZobGpTRUhPeTM0UU50UG9KRm00d1JlOGJWcnpYZzE5dks2cTJNQTJlbzY2awpYOE5XTFJ0N0d5MXh5bXNpc0ppRGk4VDlLMmhQNHNGdHdJbEZrWENubEJVMHljYlFHSWFaNmFyRHJxZ0grNGt6ClRwZ3U5Uk0wVEpadmdBbEFQRGJmN2Zzd2JxWHAwMXM0b1JTZFZIbXBSZE5KQjh0OVE0V3ZDUWhWTTBPSVBsZ3gKOTNOMHhmZHo4ZGRCMDZOa1Q3czhjSFF4N3duMHZDTUJ6RTBvTzZDY0tnWlVTS0NmdGxhd2w0Q1J3eUlxNVA0dApGNmF6VWUxMEt5RFdvOG9VV3hNYmJQNFRqSmprWDgyck9BaHZMWmpPZi85ZmJTQUc4OS84MDBkU2Z4VlM1RW1ICjlGbWVBOHIvVTVUQ3dGbFoweURNTERKZzRNL3FISVJKcXlTMEZLNVVha3lDbG01MFROdXhvU3ZKKzREVWg0dm0KbjA3MWNjbGUyT2p6ZU5BbDNmclY4UTZtOUY3UkxQdTA1RGJXOXBadjd5cWMrT000ZXRKYUpDUllaVy9ZMG0vNQo0N2tOL3lCS29LM2h5bVpiWi9NNkh2aEd5WWRpVktsdEpYZVpMU2J1MTQ4WEV5Q2tpa2xoaHJHay95WEIyN2JLCjFuVURSU1FBbGlSNnptRlhzRDUwZlFLbkw4ak4vdjNVSHQxbnlmYTczV3dGQWdNQkFBR2pQekE5TUF3R0ExVWQKRXdRRk1BTUJBZjh3RGdZRFZSMFBBUUgvQkFRREFnR0dNQjBHQTFVZERnUVdCQlNQdmZDNGlBT1ZCS2lSbnNscApINDEvdHFEZGRUQU5CZ2txaGtpRzl3MEJBUXNGQUFPQ0FnRUFKaGE4M0syL1FRUlRydkdXT1pwSU9TQ0N5S3cyCnVkMlk2Wk4raiszY00xeVo3SDA0ZWU2OTd5NVlZVGpoVzczQ2tjVm8xbEJKY1hoYmVuNXcwV0RiK254Vmdxb2gKMVRXSkZXNTBLOXhwN3Z4MHc5NnIvWkhHSVBTSU5VbExHdTF2dWFjVm5aWDA2TFNYZXZ6aHF5ZFBzeE1pQnFmRApHa1FjSlNpVDZWUThVQTlrRjJXdEtKSmEvVWtjSndxZWZGenloWEx5dWVpaXhFbUhjZ25pclB3Q05DRTcwWHJoCnZrQ1ZLaHl2Zlo5aVRnYUlEZTJwNVNpamdteFFmSDQ4VmI4TndOdnNrL24rVGFnbGtzUVM2Y3BOdmxleHhSU1MKQ3RjbmFCU253UjBibDNEdStuajB0V3FybE54YmpWbWt4SjBEUXFIdmZHeFhjS2NMYThUd2JNcERtdzUybEdNaApiZ2hCM1hESGVRbXpvNXBsL24xYVFjR200Zk9LbTZxblBNVUhNZXZCT1VGdFlRSDlYM1FQdzZMUkcraU5paFhOCnU2ZXlGd2t2WXFTRUpxdld3OFNtL0t2QUo5Z1ppQys2emVXYTNMWmZTdHdmSGJlZkREL21TdUI3NEhCNHhSaW4KV3U2N1EyOHkzQXlIa2xVTm1hNlJGaUJtcnZsTTRoVzk3bFo3TGFxQnR0Y21WWmFHbVRseUNWRTFrTTE4TEF5RgpmQWlFN3g4UzJMRHdUWW1vTGZkQm1IbWZ5ZzY0RGNWdFdDV1dueXZkY29paEhFVWVTUEhCT2FUQWdCYlFaSTFuCm5FanB1bC9uUWpiZWU3RG85eGd2cXUrV3BzTXd3WVA3bnBUR3pOb3dtQkN3NE1RMmRJSExVbTJPT3FUckNQQ0YKOHhadC9vWU9HK1J1VXg4PQotLS0tLUVORCBDRVJUSUZJQ0FURS0tLS0t
```

If you want to add your supervisor cluster as a management cluster follow this [doc](https://docs.vmware.com/en/VMware-vSphere/7.0/vmware-vsphere-with-tanzu/GUID-ED4417DC-592C-454A-8292-97F93BD76957.html)

If you want to attach a cluster, see this [doc](https://docs.vmware.com/en/VMware-Tanzu-Mission-Control/services/tanzumc-using/GUID-6DF2CE3E-DD07-499B-BC5E-6B3B2E02A070.html)