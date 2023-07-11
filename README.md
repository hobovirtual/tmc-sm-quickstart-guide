# Tanzu Mission Control Self Managed: Quickstart installation guide

## Introduction
Tanzu Mission Control has been around for quite some time and the only option to benefit from the value that it brings to platform engineering team was to subscribe to the service via the VMware Cloud Service (aka SaaS). Recently we launch an alternative deployment method for customer that couldn't benefit from Tanzu Mission Control due to various constraints, you can read more about Tanzu Mission Control Self Managed release

[Beyond SaaS: Multi-cluster Kubernetes Management for Regulated Industries and Sovereign Clouds](https://tanzu.vmware.com/content/blog/vmware-tanzu-mission-control-self-managed-announcement)

We're providing this quickstart guide to help customers installing Tanzu Mission Control Self Managed 1.0 in their private environment. This doesn't replace in any form the installation guide that can be found here, but the intent is to go over the pre-requisites and installation steps required to get this service up and running.

## Requirements
Before starting the installation process, we have to provide some components 
### Linux bootstrap machine
In order to get started you will need access to a linux operating system (x86_64), the version 1.0.0 of the tmc-sm package is only supported on linux distribution. You will also need the carvel suite installed and of course network access to the environment (see this section)

### Registry = Harbor
Tanzu Mission Control Self Managed is delivered as a set of carvel packages, the containers required for the installation, needs to be hosted in a registry, in the current release only Harbor is supported.


### Kubernetes
As previously mentioned, Tanzu Mission Control Self Managed is delivered as a set of carvel packages, we need to have access to a kubernetes cluster (version 1.23+), the cluster needs to have the following components available

- kapp-controller (installed on most Tanzu Kubernetes Clusters)
- cert-manager
- load balancer compatible with contour

### Identity Provider
Tanzu Mission Control Self Managed needs access to an external identity provider, the provider needs to be OIDC compliant.

### DNS
We need to provide a DNS zone/sub zone

- we can use external dns to manage these records
- we can create a wildcard dns zone/sub zone
- or we can manually pre-create these records

### Certificate
Trust is everything, Tanzu Mission Control Self Managed requires certificate, these certificates must be provided via a [clusterissuer](https://cert-manager.io/docs/concepts/issuer) managed by cert-manager, the clusterissuer has to be deployed prior we can start the installation procedure.


### (optional) S3 compatible storage
If you wish to backup your kubernetes environment/workloads

### (optional) Observability console
Tanzu Mission Control Self Managed adopted the batteries included approach, during the installation monitoring is installed/configured. We also provide sample grafana dashboard.

## Quickstart environment
The environment used in this quickstart is composed of the following components

| Components                    | Version   |
|-------------------------------|:---------:|
| Tanzu Kubernetes Grid cluster | 1.23.8    |
| kapp controller               | 0.46.1    |
| cert-manager                  |           |
| external-dns                  |           |