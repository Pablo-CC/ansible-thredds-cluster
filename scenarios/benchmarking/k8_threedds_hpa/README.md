# Kubernetes Thredds Cluster with HPA
In this scenario a THREDDS Cluster is deployed in Kubernetes as a single Deployment with 2 replicas (2 Pods), with an Horizontal Pod Autoscaler configured
to automatically create new replicas in order to keep the average CPU load under 50%, up to 6 replicas.

## TL;DR
`kubectl apply -f .`

## thredds-deployment.yaml
With the Deployment object you define the number of replicas and the port(s) the containers will be listening on. It uses the official [Unidata Docker container](https://hub.docker.com/r/unidata/thredds-docker/dockerfile) as the image for the containers.

```
apiVersion: apps/v1
kind: Deployment
metadata:
  name: thredds-deployment
spec:
  selector:
    matchLabels:
      app: thredds
  replicas: 2
  template:
    metadata:
      labels:
        app: thredds
    spec:
      containers:
        - name: thredds
          image: unidata/thredds-docker
          ports:
            - containerPort: 8080
          resources:
            requests:
              cpu: "200m"
              memory: "2Gi"
```
## service.yaml

With the service object configured as NodePort, all nodes in the cluster will listen to the nodePort port (`kubectl get svc thredds`).

```
apiVersion: v1
kind: Service
metadata:
  name: thredds
spec:
  selector:
    app: thredds
  type: NodePort
  ports:
    - protocol: TCP
      port: 8080
```

## horizPodAutoscaler.yaml
HPA checks for configured metric values at a default 30 second interval and tries to increase the number of replicas inside the deployment if the scecified threshold is met (with 10% tolerance).

* The metrics check interval can be configured through the `horizontal-pod-autoscaler-sync-period` flag of `kube-controller-manager`
* HPA waits (by default) 3 minutes after the last scale-up to allow metrics to stabilize (configured with `horizontal-pod-autoscaler-upscale-delay` flag)
* HPa wait for 5 minutes from the last scale-down to avoid autoscaler thrasing (configured with `horizontal-pod-autoscaler-upscale-delay` flag)

```
apiVersion: autoscaling/v1
kind: HorizontalPodAutoscaler
metadata:
  name: thredds-hpa
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: thredds-deployment
  minReplicas: 2
  maxReplicas: 6
  targetCPUUtilizationPercentage: 50

```


## Cluster Deployment

### Rancher RKE
With Rancher you can easily deploy a Kubernetes Cluster in a few steps. By default, the metrics-server component is installed so HPA can do its job.

#### Provision

* You can use the playbook at [./rke/playbooks/init-nodes.yaml] to provision the node(s) with Ansible. This playbooks installs Docker in the node(s) and creates a non-root user with SSH access able to run docker (the user needs to be in the `docker` group).
This is all you need to run RKE at your computer and create the Kubernetes cluster.

* Download [the RKE binary](https://rancher.com/docs/rke/latest/en/installation/#download-the-rke-binary)

* `mv <rke-binary> rke`

* Complete the configuration with your cluster's info:

`rke config`

* `rke up`

* Now copy the file generated with RKE as your default Kubernetes config file:

`cp kube_config_cluster.yml ~/.kube/config`

* Check that you can communicate with you cluster using kubectl:
`kubectl cluster-info`

`kubectl get nodes`

## References
* [https://github.com/Unidata/thredds-docker
* [Horizontal Pod Autoscaler - Kubernetes Docs](https://kubernetes.io/docs/tasks/run-application/horizontal-pod-autoscale/#support-for-cooldown-delay)
* [HPA Walkthrough - Kubernetes Docs](https://kubernetes.io/docs/tasks/run-application/horizontal-pod-autoscale-walkthrough/)
* [RKE Documentation](https://rancher.com/docs/rke/latest/en/)
