## Kubernetes (K8s)

Kubernetes (K8s) is an open-source platform that helps you automate the deployment, scaling, and management of containerized applications.

Think of it like a smart system that keeps your apps running smoothly — it can restart crashed apps, scale up when traffic increases, and manage multiple services across many machines.

## installation (k3s)
to install K3s (a lightweight Kubernetes distribution) on a single node, use the official install script:


curl -sfL https://get.k3s.io | sh -

test if installed with 

sudo kubectl get nodes
 
## Technology Overview


* Node: A "node" is a computer/server. Multiple nodes are joined together to form a "cluster".
* Control Plane: A subset of nodes in the cluster dedicated to performing system tasks. Nodes that are part of the control plane are referred to as "control plane nodes".
* Data Plane: A subset of nodes in the cluster dedicated to running user worklods. Nodes that are part of the data plane are referred to as "worker nodes".


## Kubernetes System Components



* etcd: Key-value store used for storing all cluster data. It serves as the source of truth for the cluster state and configuration.

* kube-apiserver: The front end for the Kubernetes control plane.

* kube-scheduler: Schedules pods onto the appropriate nodes based on resource availability and other constraints.

* kube-controller-manager: Runs controller processes. Each controller is a separate process that manages routine tasks such as maintaining the desired state of resources, managing replication, handling node operations, etc...

* cloud-controller-manager: Integrates with the underlying cloud provider (if running in one) to manage cloud-specific resources. It handles tasks such as managing load balancers, storage, and networking.

* kubelet: An agent that runs on each worker node and ensures that containers are running in pods and manages the lifecycle of containers.

* kube-proxy: This network proxy runs on each node and maintains network rules to allow communication to and from pods.


## built-in resoucrces
famous ones 



* Namespace: Provides a way to divide cluster resources between multiple users.
* Pod: The smallest and simplest Kubernetes object. Represents a set of running containers on your cluster.
* ReplicaSet: Ensures that a specified number of pod replicas are running at any given time.
* Deployment: Manages stateless applications, providing features such as rolling updates and rollbacks.
* Service: Defines a logical set of pods and a policy by which to access them.
* Job: Creates one or more pods that run to completion.
* CronJob: Schedules jobs to run at specified times or intervals.
* DaemonSet: Ensures that a copy of a pod runs on all (or some) nodes in the cluster.
* StatefulSet: Manages stateful applications, providing guarantees about the ordering and uniqueness of pods.
* ConfigMap: Store configuration data that can be consumed by pods.
* Secret: Manages sensitive information, such as passwords, OAuth tokens, and ssh keys.
* Ingress: Manages external access to the services in a cluster, typically HTTP.
* GatewayAPI: Manages traffic routing within the cluster, providing advanced routing capabilities.
* PersistentVolume and PersistentVolumeClaim: Manages persistent storage for pods.
* RBAC (Role-Based Access Control): Manages permissions within the cluster.


 
