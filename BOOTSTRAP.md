# Prerequisites

This project assumes a Linux environment with shell access, outbound internet access, and permission to install system packages and run a local Kubernetes distribution.

The setup was tested on:

- Ubuntu Server 24.04 LTS

The Kubernetes bootstrap in this document uses k3s because it provides a fast single-node setup with the core components needed for this project.

## Required tools

Install or make available:

- `curl`
- `kubectl`
- `helm`
- `make`
- `k3s`

Notes:

- Docker is **not required** for k3s itself
- k3s includes its own container runtime stack
- Docker may still be useful later for building the FastAPI image, but it is not part of cluster bootstrap

---

# Achieving the prerequisites

## 1. Update the system

```bash
sudo apt update && sudo apt upgrade -y
sudo apt install -y curl
```

## 2. Disable swap

Kubernetes expects swap to be disabled.

Disable it immediately:

```bash
sudo swapoff -a
```

Disable it persistently across reboots:

```bash
sudo sed -i '/ swap / s/^/#/' /etc/fstab
```

Verify:

```bash
swapon --show
```

Expected result:
- no output

## 3. Install k3s

This solution uses k3s as the Kubernetes distribution because it already includes the main cluster services needed for the challenge:

- local storage provisioner
- ingress controller
- node metrics
- container runtime

Install k3s:

```bash
curl -sfL https://get.k3s.io | INSTALL_K3S_VERSION="v1.35.2+k3s1" sh -
```

## 4. Verify the k3s service

Check systemd status:

```bash
sudo systemctl status k3s
```

Expected result:
- service is `active (running)`

Example:

```text
Active: active (running)
```

## 5. Verify the node is ready

Before configuring local `kubectl`, verify through the bundled k3s kubectl:

```bash
sudo k3s kubectl get nodes
```

Expected result:
- one node in `Ready` state

Example:

```text
NAME       STATUS   ROLES           AGE   VERSION
ubuntu24   Ready    control-plane   ...   v1.35.2+k3s1
```

## 6. Configure kubectl for the current user

k3s stores kubeconfig here:

- `/etc/rancher/k3s/k3s.yaml`

Copy it to the user home:

```bash
mkdir -p ~/.kube
sudo cp /etc/rancher/k3s/k3s.yaml ~/.kube/config
sudo chown "$USER:$USER" ~/.kube/config
chmod 600 ~/.kube/config
```

Verify:

```bash
kubectl get nodes
```

Expected result:
- the same `Ready` node appears without using `sudo`

## 7. Verify built-in local storage

Check storage classes:

```bash
kubectl get storageclass
```

Expected result:
- default storage class named `local-path`

Example:

```text
NAME                   PROVISIONER             RECLAIMPOLICY   VOLUMEBINDINGMODE      ALLOWVOLUMEEXPANSION   AGE
local-path (default)   rancher.io/local-path   Delete          WaitForFirstConsumer   false                  ...
```

## 8. Verify built-in ingress controller

k3s installs Traefik by default.

Check Traefik-related pods:

```bash
kubectl get pods -n kube-system | grep traefik
```

Expected result:
- installer jobs may appear as `Completed`
- the actual Traefik pod should be `Running`

Example healthy state:

```text
helm-install-traefik-crd-xxxxx   0/1   Completed   0   ...
helm-install-traefik-yyyyy       0/1   Completed   2   ...
svclb-traefik-zzzzz              2/2   Running     0   ...
traefik-xxxxxxxxxx-xxxxx         1/1   Running     0   ...
```

Notes:
- seeing `helm-install-traefik-*` pods in `Completed` is normal
- immediately after install, the Traefik installer may briefly retry or show a transient failure before settling

## 9. Verify node metrics

k3s also installs metrics-server.

Check metrics-server pod:

```bash
kubectl get pods -n kube-system | grep metrics
```

Expected result:
- `metrics-server` pod is `Running`

Then verify metrics API works:

```bash
kubectl top nodes
```

Expected result:
- CPU and memory usage are shown for the node

Example:

```text
NAME       CPU(cores)   CPU(%)   MEMORY(bytes)   MEMORY(%)
ubuntu24   581m         14%      1645Mi          13%
```

---

# Bootstrap validation checklist

Use the following commands as a quick readiness test before starting the actual platform work:

```bash
kubectl get nodes
kubectl get storageclass
kubectl get pods -n kube-system | egrep 'traefik|metrics'
kubectl top nodes
```

Expected outcome:

- node is `Ready`
- `local-path` storage class exists and is default
- `traefik` pod is running
- `metrics-server` pod is running
- `kubectl top nodes` returns real data

---

# Optional shell quality-of-life

## kubectl completion

Enable bash completion:

```bash
echo 'source <(kubectl completion bash)' >> ~/.bashrc
source ~/.bashrc
```

Test whether completion is active:

```bash
complete -p kubectl
```

If completion is enabled, this command should print completion configuration instead of failing.

---

# Troubleshooting notes

## k3s is running but Traefik installer looks failed

Right after installation, the built-in Traefik Helm job may briefly show retries or temporary failure.

Re-check after a short wait:

```bash
kubectl get pods -n kube-system | grep traefik
```

As long as the real Traefik pod becomes `Running`, the bootstrap is healthy.

## kubectl works only with sudo

That usually means the kubeconfig was not copied to the current user correctly.

Repeat:

```bash
mkdir -p ~/.kube
sudo cp /etc/rancher/k3s/k3s.yaml ~/.kube/config
sudo chown "$USER:$USER" ~/.kube/config
chmod 600 ~/.kube/config
```

Then verify again:

```bash
kubectl get nodes
```

## metrics are missing from kubectl top

If `kubectl top nodes` fails, wait a little and re-run it. metrics-server may need a short warm-up period after cluster startup.

Check the metrics-server pod:

```bash
kubectl get pods -n kube-system | grep metrics
```

---

# What is considered done

The environment is ready for the rest of the project once all of the following are true:

- `k3s` service is running
- `kubectl get nodes` shows one ready node
- `local-path` exists as default storage class
- Traefik is running
- metrics-server is running
- `kubectl top nodes` returns data

At that point, cluster bootstrap is complete and work can move to the Helm-managed platform stack.
