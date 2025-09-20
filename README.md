# 📊 Distributed Observability with Prometheus and Thanos (`remote_write`)

This project demonstrates how to **centralize metrics from multiple Kubernetes clusters** using Prometheus' `remote_write` feature in combination with **Thanos**, enabling scalable, long-term storage and unified querying.

> ⚠️ **Note**: While the architecture diagram below depicts a multi-cluster setup, for the sake of simplicity and ease of local testing, **this lab deploys everything within a single Kind cluster** — including Prometheus and the entire Thanos stack.

## 🧠 What is `remote_write`?

`remote_write` is a Prometheus feature that allows you to **forward metrics in real-time** to an external endpoint that supports the remote write API — such as **Thanos Receiver**.

With `remote_write`, you can:
- Offload metric storage to a centralized system.
- Persist metrics in long-term object storage (e.g. S3).
- Query metrics from multiple clusters in one place.
- Reduce the burden on individual Prometheus instances.

## 🧱 Architecture overview

![architecture](images/architecture.png)

### 🔍 Key Components

- **Prometheus** (deployed locally in the same cluster): configured with `remote_write`, pushing metrics to the central observability system.
- **Thanos Stack**:
  - **Receiver**: receives remote write data from Prometheus.
  - **Querier**: provides a unified PromQL API to query data across all sources.
  - **Storage Gateway** and **Compactor**: handle long-term storage into an S3-compatible backend (MinIO).
- **Grafana**: visualizes all metrics from the Thanos Querier.
- **S3 Bucket (MinIO)**: stores all metrics persistently and durably.

## ⚙️ Data Flow

1. Prometheus pushes metrics to the **Thanos Receiver** using `remote_write`.
2. The Receiver forwards the data to the **Storage Gateway**, which writes it to an **S3 bucket**.
3. The **Querier** component aggregates data from both the Receiver and the S3 bucket.
4. **Grafana** queries the Querier to visualize the metrics.

## 🚀 Benefits

- 🔁 Long-term storage of Prometheus metrics.
- 📡 Centralized observability, even in a single cluster.
- 🧩 Easily extensible to a multi-cluster setup with more Prometheus instances.
- 💾 Cost-effective and scalable object storage (S3/MinIO).
- 📊 Fully compatible with Grafana and native Prometheus queries.

## 🧪 Local Lab Setup with Kind & ArgoCD

This project includes a fully local observability stack based on **Prometheus**, **Thanos**, **MinIO**, and **Grafana**, orchestrated with **ArgoCD**, all running inside a single [Kind](https://kind.sigs.k8s.io/) Kubernetes cluster.

### 📦 Requirements

- Docker
- kubectl
- kind
- helm
- argocd CLI
- GNU bash (for the `setup.sh` script)
- (Optional) `jq` and `curl` for debugging

### 🚀 Deploy the lab

#### 1. Deploy Cluster and install ArgoCD

To spin up the environment locally:

```bash
./01-environment-setup/setup.sh
```

This script will:

  1. Create a Kind cluster using the config in clusters/kind-master.yaml.

  2. Install NGINX Ingress and MetalLB.

  3. Deploy ArgoCD and login automatically.

> ⚠️ Note: The lab assumes all services (ArgoCD, Grafana, etc.) will be exposed using MetalLB and reachable via custom local domains (e.g. `grafana.local`, `argocd.myorg.com`). You can add these to your `/etc/hosts` file like this:

```bash
# Example /etc/hosts entries
172.18.0.240  argocd.myorg.com grafana.local prometheus.local minio-console.local querier-thanos.local
```

#### 2. Deploy Grafana Stack

1. Deploy Minio

```bash
kubectl apply -f 02-argocd/01-minio-operator/application.yaml
kubectl apply -f 02-argocd/02-minio-tenant/application.yaml
```

Access Minio UI and create "Access Keys".

Update `02-argocd/03-thanos/minio-objectstoresecret.yaml` Access Key values. 

2. Deploy Thanos

```bash
kubectl create ns monitoring
kubectl apply -f 02-argocd/03-thanos/minio-objectstoresecret.yaml
kubectl apply -f 02-argocd/03-thanos/application.yaml
```

3. Deploy Grafana and Prometheus

```bash
kubectl apply -f 02-argocd/04-grafana/application.yaml
kubectl apply -f 02-argocd/05-prometheus/application.yaml
```

> 💡 Reminder: Configure Grafana Datasource
  After deployment, **remember to add Thanos Querier as a Prometheus datasource in Grafana** to visualize all the aggregated metrics (already done in grafana values.yaml):
  `http://thanos-query.monitoring.svc.cluster.local:9090`



### 🌐 Access Services

| Service        | URL                                     | Notes                      |
|----------------|-----------------------------------------|----------------------------|
| ArgoCD         | https://argocd.myorg.com                | Argo UI for app management |
| Grafana        | https://grafana.local                   | Metrics visualization      |
| Prometheus     | https://prometheus.local:8444           | Prometheus UI (via Ingress)|
| MinIO Console  | https://minio-console.local             | S3-compatible storage UI   |
| Thanos Querier | https://querier-thanos.local            | Unified PromQL interface   |


## 🔗 References
- [A Thanos Remote Write: Scaling Metrics with Ease – Part 1](https://medium.com/@mohitverma160288/thanos-remote-write-scaling-metrics-with-ease-part1-eb861b9aefa9)
- [thanos-remote-write (GitHub)](https://github.com/mvtech88/thanos-remote-write)
- [Thanos (Multi-Cluster Prometheus) Tutorial: Global View – Long-Term Storage – Kubernetes](https://www.youtube.com/watch?v=feHSU0BMcco&t=776s)
- [Thanos (Prometheus) Tutorial: Remote Read/Write – mTLS – Step-by-Step!](https://github.com/antonputra/tutorials/tree/main/lessons/163)
- [Thanos Remote Receive Documentation](https://thanos.io/v0.10/201812_thanos-remote-receive.md/)
