---
title: "K3s and external NFS storage"
date: "2023-06-25"
author: "Mark"
tags: ["k8s", "nfs", "k3s"]
keywords: ["k8s", "nfs", "k3s"]
description: "Using NFS with k3s"
showFullContent: false
draft: false
series: ["homelab"]
summary: "Using NFS with k3s"
---

# Howdy 👋

I've been running [k3s](https://k3s.io) for a long time, it's a great project. I've been using it to run a few things on my home network and I've been using NFS to share files between nodes.

While this post is just a writeup of what I've done, it should be detailed enough for someone to replicate. To do so you'll need a k3s cluster(could be a single raspberry pi or virtual machine) and an NFS server. I'm using a single node k3s cluster and a NAS for the NFS server.

## The NFS Server

I'm using a NAS, so all I had to do was enable NFS and create a share, whitelisting the IP of my single test k3s node.

## The NFS Client

I've got a virtual machine to run K3s on. Before moving to installing K3s let's test that the client can mount the NFS share:

```bash
# install nfs-common package for mounting NFS shares if using Ubuntu
apt install nfs-common
# check that the share is available
showmount -e <server>
# create a mount point and mount the share
mkdir /tmp/nfscheck
mount -t nfs <server>:<path> /tmp/nfscheck
# check that the share is mounted
msh@k3s-00:/tmp$ df -h /tmp/nfscheck
Filesystem                                  Size  Used Avail Use% Mounted on
nas.fqdn.here:/volume1/k8s-nfs  7.3T   36G  7.3T   1% /tmp/nfscheck

# unmount the share once you're done
umount /tmp/nfscheck
```

## Installing K3s

Install k3s on the NFS client node using their [install script](https://rancher.com/docs/k3s/latest/en/installation/install-options/)

```bash
curl -sfL https://get.k3s.io | sh -
```

Wait a little for things to settle down and check the node is ready (k3s takes care of the kubeconfig for you):

```bash
# make you run this on the node you installed k3s on or have grabbed the kubeconfig from the node
kubectl get node
```

You may check which storage classes are available:

```bash
kubectl get storageclasses

NAME                   PROVISIONER             RECLAIMPOLICY   VOLUMEBINDINGMODE      ALLOWVOLUMEEXPANSION   AGE
local-path (default)   rancher.io/local-path   Delete          WaitForFirstConsumer   false                  0h05m

```

## Configuring K3s to use NFS

Using the built in helm controller makes this a breeze:

```bash
nano /var/lib/rancher/k3s/server/manifests/helm-controller.yaml
apiVersion: v1
kind: Namespace
metadata:
  name: nfs
---
apiVersion: helm.cattle.io/v1
kind: HelmChart
metadata:
  name: nfs
  namespace: nfs
spec:
  chart: nfs-subdir-external-provisioner
  repo: https://kubernetes-sigs.github.io/nfs-subdir-external-provisioner
  targetNamespace: nfs
  set:
    nfs.server: x.x.x.x # IP of the NFS server or fqdn
    nfs.path: /exported/path # path to the NFS share
    storageClass.name: nfs
```

Save the file and wait a little for the helm controller to do its thing.
If we recheck the [storage classes](https://kubernetes.io/docs/concepts/storage/storage-classes/) we should see the new NFS storage class:

```bash
root@k3s-00:~# kubectl get storageclasses
NAME                   PROVISIONER                                         RECLAIMPOLICY   VOLUMEBINDINGMODE      ALLOWVOLUMEEXPANSION   AGE
local-path (default)   rancher.io/local-path                               Delete          WaitForFirstConsumer   false                  25m
nfs                    cluster.local/nfs-nfs-subdir-external-provisioner   Delete          Immediate              true                   20m
```

## Creating a Persistent Volume Claim

Let's test that we can create a PVC (Persistent Volume Claim) and that it gets bound to a PV (Persistent Volume). We'll use a simple manifest to do this:

```yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: nfsclaim
spec:
  accessModes:
    - ReadWriteOnce
  storageClassName: nfs
  resources:
    requests:
      storage: 100Mi
```

Let’s save that manifest as pvc.yaml, create the PVC and check that it gets bound to a PV:

```bash
kubectl apply -f pvc.yaml
persistentvolumeclaim/nfsclaim created

kubectl get pvc nfsclaim
NAME       STATUS   VOLUME                                     CAPACITY   ACCESS MODES   STORAGECLASS   AGE
nfsclaim   Bound    pvc-bdd42e9b-a2b0-4e9b-9737-ea068a486f16   100Mi      RWO            nfs            54m
```

## Next Steps

### Using the PVC with a pod

Here's a simple example for using the PVC with a pod:

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: nfs-pod
spec:
  containers:
    - name: nfs-pod
      image: nginx
      volumeMounts:
        - name: nfs-volume
          mountPath: /usr/share/nginx/html
  volumes:
    - name: nfs-volume
      persistentVolumeClaim:
        claimName: nfsclaim
```

Other things to look at in the future will be backups and recovery of the nfs volume and PVCs.
