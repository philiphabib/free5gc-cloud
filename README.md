# free5GC Cloud-Native Platform

Cloud-native deployment of free5GC v4.2.3 on Kubernetes.

## Platform

- Kubernetes v1.36.2
- Calico CNI
- MetalLB
- NFS CSI
- Argo CD
- Prometheus
- Grafana

## Nodes

- k8s-worker1: compute
- k8s-worker2: compute
- k8s-worker3: dedicated storage

## Network

- LAN: 192.168.122.0/24
- Pod CIDR: 10.244.0.0/16
- MetalLB pool: 192.168.122.230-192.168.122.240

## free5GC

Version: v4.2.3

N2:
SCTP/38412

N3:
GTP-U/2152

N4:
PFCP/8805

Nwu:
IKE/500
IKE NAT-T/4500

GitOps verification test
