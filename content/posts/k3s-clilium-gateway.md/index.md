---
title: "HA K3s with Cilium and Gateway API"
date: "2023-08-14"
author: "Mark"
tags: ["k8s", "cilium", "k3s", "gateway-api", "proxmox"]
keywords: ["k8s", "cilium", "k3s", "gateway-api", "proxmox"]
description: "Configuring HA K3S with Cilium and Gateway API"
showFullContent: false
draft: false
series: ["homelab"]
summary: "Adventures with K8S, cilium and the gateway API"
---

# Howdy 👋

This post is two things; **long** and **to the point**. While one might be able to follow
along and replicate what was done here, it will require a setup like mine
to be able to run the same commands without modification.

The aim was to create a highly available k3s cluster with CNI provided by Cilium, utilising
L2 announcements and Gateway API to provide external access to services. A lot of what
was done here is experimental and in beta, so it's not recommended for production use.

> I won't explain every command or choice made, otherwise this post would be even longer. It is assumed that the reader knows enough to be dangerous.

## The plan

* Create a highly available k3s cluster using proxmox
* Install cilium and configure it to use L2 announcements, IP IPAM and Gateway API
* Install cert-manager and configure it to use letsencrypt and gateway API instead of ingress
* Install external-dns and configure it to use gateway API instead of ingress
* Deploy a test application and expose it using gateway API, cert-manager and external-dns

Here is a confusing and probably not useful diagram of the setup:

{{< mermaid >}}
graph TD
  subgraph k3s Cluster

    subgraph Control Plane
      CP1[Control Plane Node 1]
      CP2[Control Plane Node 2]
      CP3[Control Plane Node 3]
    end
    subgraph Worker Nodes
      W1[Worker Node 1]
      W2[Worker Node 2]
      SLB[Service LoadBalancer]
      W2 --> SLB
    end

  end
  
  subgraph Cilium CNI

    Cilium[Cilium]
    L2A["L2 Announcements"]
    IPAM["IP IPAM"]
    GatewayAPI["Gateway API"]
    HTTPR[HTTPRoute]
    GatewayAPI --> HTTPR
    GatewayAPI -- controls --> SLB

  end
  
  subgraph External DNS

    HTTPR -- annotation triggers --> ExternalDNS
    ExternalDNS[external-dns]
    ExternalDNS -- registers --> Pihole[Pi-hole]
    Pihole -- resolves --> SLB

  end

  subgraph Cert Manager

    CM[cert-manager]
    CF[Cloudflare DNS Challenge]
    CM --> CF
    HTTPR -- annotation triggers --> CM
    CF -- creates --> Cert[Certificate]
    Cert -- provides --> SLB

  end

  Cilium -- controls --> L2A
  Cilium -- controls --> IPAM
  Cilium -- integrates with --> GatewayAPI
  SLB -- gets IP from --> IPAM
  L2A -- announces on --> W2
  
  CP1 --> Cilium
  CP2 --> Cilium
  CP3 --> Cilium
  W1 --> Cilium
  W2 --> Cilium
  
  style Cilium fill:#3c3836
  style CP1 fill:#282828
  style CP2 fill:#282828
  style CP3 fill:#282828
  style W1 fill:#504945
  style W2 fill:#504945
  style SLB fill:#928374
  style CM fill:#b8bb26
  style ExternalDNS fill:#fabd2f
  style CF fill:#d3869b
  style GatewayAPI fill:#d65d0e
  style L2A fill:#8ec07c
  style IPAM fill:#83a598
{{< /mermaid >}}

Here's a totally less confusing diagram of the end state:

{{< figure

    src="Untitled-2022-04-23-2011.svg"
    alt="architecture"
    caption="L2 announcements FTW"
    >}}

The idea here is that the worker node will layer 2 announce it's own IP and the IPs of
services exposed externally in the cluster.

## The Setup

Five virtual machines. A Proxmox VM Template was used, with Packer providing the template
configuration. Each one had a single network interface (all had the same interface name
), suitable ssh public key and working DNS. DHCP and reserved addresses were used, but
static addresses would work just as well. Three of these were for the control plane, two for worker nodes.

> Success Critera: ssh to each node, ping each node from each other node, ping google.com.

## The Cluster

On the first VM, k3s was installed using the [install script](https://rancher.com/docs/k3s/latest/en/installation/install-options/). This was the first control plane node.

> Note the `K3S_TOKEN` environment variable and `--tls-san=` flag.
> Flannel backend, network policy, service lb, traefik and metrics-server were disabled as cilium was used instead.

```bash
curl -sfL https://get.k3s.io | K3S_TOKEN=some-token-here sh -s - server --cluster-init --tls-san=$(ip -brief address show enp6s18 | awk '{print $3}' | awk -F/ '{print $1}') --flannel-backend=none --disable-network-policy --disable "servicelb" --disable "traefik" --disable "metrics-server"
```

On the other two control plane nodes a similar command was run, but without the `--cluster-init` flag:

> The command is very similar to the above, but without the `--cluster-init` flag and has the `--server` flag (with the IP of the first control plane node).

```bash
curl -sfL https://get.k3s.io | K3S_TOKEN=some-token-here sh -s - server --server https://192.168.0.142:6443 --tls-san=$(ip -brief address show enp6s18 | awk '{print $3}' | awk -F/ '{print $1}') --flannel-backend=none --disable-network-policy --disable "servicelb" --disable "traefik" --disable "metrics-server"
```

The worker nodes were installed using a similar command, but with the `server` flag and the IP of the first control plane node:

```bash
curl -sfL https://get.k3s.io | K3S_TOKEN=some-token-here sh -s - agent --server https://192.168.0.142:6443
```

At this point the cluster was up and running. In the example below there was one worker and three control plane nodes.
The kubeconfig was copied from the first control plane node to the local machine and used to access the cluster to run this command.

> Until Cilium is installed the nodes will not be `ready` .

```bash
➜  kubectl get nodes -o json | jq '.items[] | {name: .metadata.name, status: .status.conditions[] | select(.type=="Ready") .type, roles: [(.metadata.labels | to_entries[] | select(.key | startswith("node-role.kubernetes.io/")) .key)]}'
```

Some output:

```json
{
  "name": "node-1",
  "status": "Ready",
  "roles": [
    "node-role.kubernetes.io/control-plane",
    "node-role.kubernetes.io/etcd",
    "node-role.kubernetes.io/master"
  ]
}
{
  "name": "node-2",
  "status": "Ready",
  "roles": [
    "node-role.kubernetes.io/control-plane",
    "node-role.kubernetes.io/etcd",
    "node-role.kubernetes.io/master"
  ]
}
{
  "name": "node-3",
  "status": "Ready",
  "roles": [
    "node-role.kubernetes.io/control-plane",
    "node-role.kubernetes.io/etcd",
    "node-role.kubernetes.io/master"
  ]
}
{
  "name": "worker-01",
  "status": "Ready",
  "roles": []
}
```

> Success Criteria: `kubectl get nodes` shows all nodes.

## Cilium

At this point, kube-system pods were not running. A CNI plugin was needed to get the cluster up and running.

### Install Cilium CRDs

This needed to be done before installing cilium itself.

```bash
kubectl apply -f https://raw.githubusercontent.com/kubernetes-sigs/gateway-api/v0.7.0/config/crd/standard/gateway.networking.k8s.io_gatewayclasses.yaml

kubectl apply -f https://raw.githubusercontent.com/kubernetes-sigs/gateway-api/v0.7.0/config/crd/standard/gateway.networking.k8s.io_gateways.yaml

kubectl apply -f https://raw.githubusercontent.com/kubernetes-sigs/gateway-api/v0.7.0/config/crd/standard/gateway.networking.k8s.io_httproutes.yaml

kubectl apply -f https://raw.githubusercontent.com/kubernetes-sigs/gateway-api/v0.7.0/config/crd/standard/gateway.networking.k8s.io_referencegrants.yaml

kubectl apply -f https://raw.githubusercontent.com/kubernetes-sigs/gateway-api/v0.7.0/config/crd/experimental/gateway.networking.k8s.io_tlsroutes.yaml
```

### Install Cilium

> Note the `k8sServiceHost` and `k8sServicePort` flags. These are the IP and port of the first control plane node.

```bash

brew install cilium-cli

helm repo add cilium https://helm.cilium.io/

helm install cilium cilium/cilium --version 1.14.0 \
   --namespace kube-system \
   --reuse-values \
   --set operator.replicas=1 \
   --set kubeProxyReplacement=true \
   --set l2announcements.enabled=true \
   --set k8sClientRateLimit.qps=32 \
   --set k8sClientRateLimit.burst=60 \
   --set kubeProxyReplacement=strict \
   --set k8sServiceHost=192.168.0.142 \
   --set k8sServicePort=6443 \
   --set gatewayAPI.enabled=true
```

> Success Criteria: `kubectl get pods -n kube-system` shows all pods as running. `cilium status` shows as `ok` .

### IP IPAM

A small chunk of 192.168.0.1/24 was reserved for cilium to use for IPAM. This was done by creating a new IP pool:

```yaml
apiVersion: "cilium.io/v2alpha1"
kind: CiliumLoadBalancerIPPool
metadata:
  name: "home-lab-pool"
spec:
  cidrs:
    - cidr: "192.168.0.192/26"
```

> Success Criteria: `kubectl get ciliumloadbalancerippool` shows the pool as `disabled = false` and `conflicting = false` .

### L2 Announcements

A L2 announcement policy was created to allow nodes to announce their services to the world.

> Note the `nodeSelector` and `serviceSelector` fields. These are used to select which nodes and services are allowed to announce themselves.

```yaml
apiVersion: "cilium.io/v2alpha1"
kind: CiliumL2AnnouncementPolicy
metadata:
  name: default-policy
spec:
  serviceSelector:
    matchLabels:
      io.cilium.gateway/owning-gateway: my-gateway
  nodeSelector:
    matchExpressions:
      - key: node-role.kubernetes.io/control-plane
        operator: DoesNotExist
  loadBalancerIPs: true
```

> Success Criteria: `kubectl get ciliuml2announcementpolicy` shows the policy.

### External DNS

External DNS was installed with gateway support to allow DNS records on the pihole to be created for services.

> Note the `--source=gateway-httproute` flag. This is used to tell external-dns to use the gateway API instead of ingress.

> Note the secret, don't commit this to git!

```yaml
---
apiVersion: v1
kind: ServiceAccount
metadata:
  name: external-dns
---
apiVersion: v1
kind: Secret
metadata:
  name: pihole-password
type: Opaque
data:
  EXTERNAL_DNS_PIHOLE_PASSWORD: some-password-here
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: external-dns
rules:
  - apiGroups: [""]
    resources: ["namespaces"]
    verbs: ["get", "watch", "list"]
  - apiGroups: ["gateway.networking.k8s.io"]
    resources:
      [
        "gateways",
        "httproutes",
        "grpcroutes",
        "tlsroutes",
        "tcproutes",
        "udproutes",
      ]
    verbs: ["get", "watch", "list"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: external-dns-viewer
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: external-dns
subjects:
  - kind: ServiceAccount
    name: external-dns
    namespace: default
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: external-dns
spec:
  strategy:
    type: Recreate
  selector:
    matchLabels:
      app: external-dns
  template:
    metadata:
      labels:
        app: external-dns
    spec:
      serviceAccountName: external-dns
      containers:
        - name: external-dns
          image: registry.k8s.io/external-dns/external-dns:v0.13.5
          # If authentication is disabled and/or you didn't create
          # a secret, you can remove this block.
          envFrom:
            - secretRef:
                # Change this if you gave the secret a different name
                name: pihole-password
          args:
            # Add desired Gateway API Route sources.
            - --source=gateway-httproute
            # Pihole only supports A/CNAME records so there is no mechanism to track ownership.
            # You don't need to set this flag, but if you leave it unset, you will receive warning
            # logs when ExternalDNS attempts to create TXT records.
            - --registry=noop
            # IMPORTANT: If you have records that you manage manually in Pi-hole, set
            # the policy to upsert-only so they do not get deleted.
            - --policy=upsert-only
            - --provider=pihole
            # Change this to the actual address of your Pi-hole web server
            - --pihole-server=https://pihole.url.here
      securityContext:
        fsGroup: 65534 # For ExternalDNS to be able to read Kubernetes token files
```

> Success Criteria: `kubectl get pods -n external-dns` shows all pods as running.

### Cert Manager

Cert Manager also needed to be installed with gateway support to allow certificates to be created for services:

```yaml
helm repo add jetstack https://charts.jetstack.io

helm install \
  cert-manager jetstack/cert-manager \
  --namespace cert-manager \
  --create-namespace \
  --version v1.12.0 \
  --set "extraArgs={--feature-gates=ExperimentalGatewayAPISupport=true}"
```

A certificate issuer was created to allow letsencrypt to be used with DNS challenges:

> Note the secret, don't commit this to git!

```yaml
---
apiVersion: v1
kind: Secret
metadata:
  name: cloudflare-api-token-secret
  namespace: cert-manager
type: Opaque
stringData:
  api-token: some-token-here
---
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: lets-encrypt-prod
  namespace: cert-manager
spec:
  acme:
    # The ACME server URL
    server: https://acme-v02.api.letsencrypt.org/directory
    # Email address used for ACME registration
    email: le@email.com
    # Name of a secret used to store the ACME account private key
    privateKeySecretRef:
      name: lets-encrypt-prod-account-key
    solvers:
      - dns01:
          cloudflare:
            apiTokenSecretRef:
              name: cloudflare-api-token-secret
              key: api-token
```

> Success Criteria: `kubectl get pods -n cert-manager` shows all pods as running.
>  
> Additionally: check a cert can be issued by creating a certificate resource.

At this point, the cluster was up and running with cilium providing CNI and L2 Announcements, external-dns providing DNS records and cert-manager providing certificates.

It was time to deploy a test application.

## Deploying A Test Application

```yaml
---
apiVersion: gateway.networking.k8s.io/v1beta1
kind: Gateway
metadata:
  name: my-gateway
  namespace: default
  labels:
    gateway: my-gateway
spec:
  gatewayClassName: cilium
  listeners:
    - name: https-listener
      hostname: demo.internal.sharpley.xyz
      protocol: HTTPS
      port: 443
      allowedRoutes:
        namespaces:
          from: All
      tls:
        mode: Terminate
        certificateRefs:
          - name: nginx-le-cert
            namespace: default
            kind: Secret
---
apiVersion: gateway.networking.k8s.io/v1beta1
kind: HTTPRoute
metadata:
  name: nginx-hello-route
  labels:
    gateway: my-gateway
  annotations:
    cert-manager.io/cluster-issuer: lets-encrypt-prod
    external-dns.alpha.kubernetes.io/hostname: "demo.internal.sharpley.xyz"
spec:
  parentRefs:
    - name: my-gateway
      namespace: default
      sectionName: https-listener
  rules:
    - matches:
        - path:
            type: PathPrefix
            value: /
      backendRefs:
        - name: nginx-hello-service
          port: 80
---
apiVersion: v1
kind: Service
metadata:
  name: nginx-hello-service
spec:
  selector:
    app: nginx-hello
  ports:
    - protocol: TCP
      port: 80
      targetPort: 80
---
apiVersion: v1
kind: Pod
metadata:
  name: nginx-hello
  labels:
    app: nginx-hello
spec:
  containers:
    - name: nginx
      image: nginx:alpine
      ports:
        - containerPort: 80

```

Here are a few commands to check that things worked as expected:

```bash
kubectl get gateways.gateway.networking.k8s.io -l gateway=my-gateway
NAME         CLASS    ADDRESS         PROGRAMMED   AGE
my-gateway   cilium   192.168.0.254   True         12h

kubectl get service cilium-gateway-my-gateway
NAME                        TYPE           CLUSTER-IP     EXTERNAL-IP     PORT(S)         AGE
cilium-gateway-my-gateway   LoadBalancer   10.43.23.131   192.168.0.254   443:32750/TCP   12h

dig demo.internal.sharpley.xyz A +short
192.168.0.254

ping demo.internal.sharpley.xyz
PING demo.internal.sharpley.xyz (192.168.0.254): 56 data bytes
92 bytes from worker-01.internal.sharpley.xyz (192.168.0.18): Redirect Host(New addr: 192.168.0.254)
Vr HL TOS  Len   ID Flg  off TTL Pro  cks      Src      Dst
 4  5  00 0054 4532   0 0000  3f  01 b39b 192.168.0.141  192.168.0.254

```

> Success Criteria: curl the URL...

```bash
curl -I -L https://demo.internal.sharpley.xyz

HTTP/1.1 200 OK
server: envoy
date: Mon, 14 Aug 2023 22:33:39 GMT
content-type: text/html
content-length: 615
last-modified: Tue, 13 Jun 2023 17:34:28 GMT
etag: "6488a8a4-267"
accept-ranges: bytes
x-envoy-upstream-service-time: 0
```

## Next Steps

* Deploy a real application
* Integrate with a CD system, probably Flux
