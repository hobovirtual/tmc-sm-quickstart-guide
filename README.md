# Tanzu Mission Control - Self-Managed QuickStart

This is for testing and evaluation purposes only. This QuickStart guide is intended to install Tanzu Mission Control with minimal requirements. For production use cases, please refer to the official [documentation](https://docs.vmware.com/en/VMware-Tanzu-Mission-Control/1.1/tanzumc-sm-install/index-sm-install.html)

Tanzu Mission Control, is a centralized hub for simplified, multi-cloud, multi-cluster Kubernetes management. More information can be found [here](https://Tanzu.vmware.com/mission-control)

Tanzu Mission Control has been available to operators as a SaaS offering but is now available as a deployable application to supported Kubernetes clusters called Tanzu Mission Control Self-Managed. This enables customers to utilize the fleet-wide management capabilities of Tanzu Mission Control in organizations where SaaS services are restricted, organizations that need complete application control, or air-gapped environments.

Read more about Tanzu Mission Control Self-Managed in this [release blog](https://Tanzu.vmware.com/content/blog/vmware-Tanzu-mission-control-self-managed-announcement)

# QuickStart Introduction
But what if you're just looking for a quick and easy way to test Tanzu Mission Control Self-Managed in your lab/test environment? 

Well, we got you covered, this QuickStart guide will guide you through the installation with minimal set of requirements.

## Prerequisite
- vSphere with Tanzu enabled on a vSphere cluster
- Active Directory
- An Intel based operating system with
    - docker desktop installed
- A network accessible Harbor Registry
    - you need one public project for Tanzu Mission Control Self-Managed images
    - access to Tanzu packages repository - you can use the public repo projects.registry.vmware.com/tkg/packages/standard/repo
        - if you're working with an internet restricted environment you can copy the pacakges with this command
```
imgpkg copy -b projects.registry.vmware.com/tkg/packages/standard/repo:v2023.11.21 --to-repo $HARBOR_HOSTNAME/tkg/packages/standard/repo
```

## In this guide we will deploy the following components
- Tanzu kubernetes cluster 1.2+
- cert-manager 0.11+
    - clusterissuer using a self-signed certificate (included)
- external-dns for dynamic dns configuration - this is optional but recommended "*"
    - the values provided in this guide are for configuring external-dns with a BIND server, if you're planning to use other or if you want more configuration option, please refer to this [docs](https://docs.vmware.com/en/VMware-Tanzu-Kubernetes-Grid/1.6/vmware-Tanzu-kubernetes-grid-16/GUID-packages-external-dns.html#prepare-the-configuration-file-for-the-externaldns-package-3)

![Tanzu Mission Control Self-Managed](pictures/tmc-sm.jpg)

"*" *If you don't want to use dynamic dns configuration you can create two dns entries manually*
- tmc.mydomain.com 
- *.tmc.mydomain.com

DNS entries will point to the contour-envoy load balancer IP once deployed in step 6 - you can easily retrieve the IP using this command
```
kubectl -n tmc-local get svc contour-envoy -o jsonpath={'.status.loadBalancer.ingress[0].ip'}
```

## The following steps have been tested on the following environment
- vSphere 8.0 Update 2
    - Supervisor 1.26.4
    - Tanzu Kubernetes Cluster 1.26.5
    - Latest supported Tanzu Packages (v2023.11.21)
- Microsoft Active Directory 

# installation steps

## 1 - clone this repo
```
git clone https://github.com/hobovirtual/tmc-sm-quickstart-guide --branch=1.1
cd tmc-sm-quickstart-guide
```

## 2 - Instalaltion configuration and Local variables definition
### 2.1 Installation configuration
Review and replace all values in {{}} and update with your own
#### config/common-values.yaml

| component | template value | example value |
| --------- | -------------- | ---------- |
| tkg | {{clustername}} | tkc-sm-00 |
| tkg | {{vsphere-namespace}} | vns-sandbox |
| tkg | {{tkr-version}} | v1.26.5---vmware.2-fips.1-tkg.1 |
| tkg | {{storageclass}} | vsan-default-storage-policy |
| tmc | {{mydomain.com}} | tmc.tanzu.lab |
| external-dns | {{owner id}} | tmc.tanzu.lab |
| external-dns | {{dns1, dns2}} | 192.168.2.1,192.168.1.1 |
| external-dns | {{dns zone}} | tanzu.lab |
| external-dns | {{domain filter}} | tanzu.lab |
| active directory | {{domain admin group}} | tmc-administrators |
| active directory | {{domain name}} | tanzu.lab |
| active directory | {{groupbase search dn}} | OU=groups,OU=platform,DC=tanzu,DC=lab |
| active directory | {{domain controller|name}} | tanzu.lab |
| active directory | {{domain users group}} | tmc-users |
| active directory | {{username password}} | VMware1! |
| active directory | {{userbase search dn}} | OU=users,OU=platform,DC=tanzu,DC=lab |
| active directory | {{username dn}} | CN=svc-ldap,OU=service-accounts,OU=users,OU=platform,DC=tanzu,DC=lab |
| active directory | rootCA | Active Directory Certificate |
| registry | {{myharbor.mydomain.com}} | harbor.tanzu.lab |
| registry | {{myproject}} | tmc |
| registry | {{ -----BEGIN CERTIFICATE----- -----END CERTIFICATE-----}} | your harbor certificate |

*NOTE: If you don't want to use external-dns, you can either remove the section from the secrets.yaml and pkgi.yaml files or leave the default*

### 2.2 Local variables definition
Update each variables values with your own

```
export HARBOR_HOSTNAME=myharbor.domain.com
export HARBOR_USERNAME=myuser
export HARBOR_PASSWORD=mypassword
export HARBOR_PROJECT=myproject
export SUPERVISOR=ip|hostname
export SUPERVISOR_USERNAME=supervisorusername
export SUPERVISOR_PASSWORD=supervisorpassword

```

## 3 - push images to your harbor registry
### 3.1 - download and extract Tanzu Mission Control Self-Managed installer in the current directory (from your X86_X64 machine)
download from the [Customer Connect download site](https://customerconnect.vmware.com/en/downloads/info/slug/infrastructure_operations_management/vmware_tanzu_mission_control_self_managed/1_1_0)

```
mkdir tmc
tar -xf tmc-self-managed-1.1.0.tar -C ./tmc
```

### 3.2 - add your harbor certificate
Update the bootstrap/harbor.crt file with your harbor certificate

### 3.3 - build local docker image
Now let's build our local docker image that will do the work for us

```
docker build -t bootstrap bootstrap/.
```

### 3.4 - push images to harbor
```
docker run --rm -v $PWD/scripts:/work/scripts -v $PWD/images:/work/images -v $PWD/tmc:/work -e IMGPKG_REGISTRY_HOSTNAME=$HARBOR_HOSTNAME -e PROJECT=$HARBOR_PROJECT -e IMGPKG_REGISTRY_USERNAME=$HARBOR_USERNAME -e IMGPKG_REGISTRY_PASSWORD=$HARBOR_PASSWORD -it bootstrap push-images
```

## 4 - create a Tanzu kubernetes cluster
```
docker run --rm -v $PWD/config:/work/config -v $PWD/scripts:/work/scripts -v $PWD/tkc:/work/tkc -e SUPERVISOR=$SUPERVISOR -e USERNAME=$SUPERVISOR_USERNAME -e KUBECTL_VSPHERE_PASSWORD=$SUPERVISOR_PASSWORD -it bootstrap cluster
```

## 5 - install and configure tanzu packages
```
docker run --rm -v $PWD/config:/work/config -v $PWD/scripts:/work/scripts -v $PWD/tkc:/work/tkc -v $PWD/packages:/work/packages -e SUPERVISOR=$SUPERVISOR -e USERNAME=$SUPERVISOR_USERNAME -e KUBECTL_VSPHERE_PASSWORD=$SUPERVISOR_PASSWORD -it bootstrap tanzu-packages
```

## 6 - install configure Tanzu Mission Control Self-Managed
```
docker run --rm -v $PWD/config:/work/config -v $PWD/scripts:/work/scripts -v $PWD/tkc:/work/tkc -v $PWD/packages:/work/packages -e SUPERVISOR=$SUPERVISOR -e USERNAME=$SUPERVISOR_USERNAME -e KUBECTL_VSPHERE_PASSWORD=$SUPERVISOR_PASSWORD -it bootstrap tmc-install
```

*please note the Tanzu misssion control self-managed installation can take several minutes*
# What's next??
Tanzu Mission Control Self-Managed has now been successfully deployed! Access the interface by following using the active directory credentials via the url below.

https://tmc.{{mydomain.com}}

## Complete the Registration of a Supervisor Cluster in vSphere with Tanzu
To ensure new Tanzu Kubernetes Grid clusters can be managed by Tanzu Mission Control, you will need to add an AgentConfig as describe [here](https://docs.vmware.com/en/VMware-Tanzu-Mission-Control/1.1/tanzumc-using/GUID-CC6E721E-43BF-4066-AA0A-F744280D6A03.html#GUID-CC6E721E-43BF-4066-AA0A-F744280D6A03). 

Retrieve the tmc namespace for your supervisor installation 

```
export TMCNS=`kubectl get ns | grep svc-tm | cut -d" " -f1` 
```

Apply the AgentConfig to your Supervisor Cluster

```
kubectl vsphere login --insecure-skip-tls-verify --server $SUPERVISOR -u $SUPERVISOR_USERNAME
kubectl config set-context $SUPERVISOR
ytt -f config/common-values.yaml -f packages/tmc/agentconfig.yaml | kubectl apply -n $TMCNS -f -
```

You can now proceed with the management cluster registration as described [here](https://docs.vmware.com/en/VMware-Tanzu-Mission-Control/1.1/tanzumc-using/GUID-EB507AAF-5F4F-400F-9623-BA611233E0BD.html#procedure-2)

## Copying Tanzu Standard and Inspection Images
Copy the Tanzu Standard package and the third-party Sonobouy inspection scan images to your private image registry by following this [procedure](https://docs.vmware.com/en/VMware-Tanzu-Mission-Control/1.1/tanzumc-sm-install/tanzu-conf-images.html)