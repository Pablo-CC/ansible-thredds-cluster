# Kubernetes Thredds Cluster with HPA and Ingress Controller
In this scenario two THREDDS Clusters are deployed in Kubernetes (a `catalog` cluster and a `data` cluster), each one as a single Deployment with 2 replicas (2 Pods), with an Horizontal Pod Autoscaler configured
to automatically create new replicas in order to keep the average CPU load under 50%, up to 6 replicas for each Deployment. 

Additionally, an Ingress Controller will be deployed in Kubernetes, using [a Helm chart](https://github.com/helm/charts/tree/master/stable/nginx-ingress), that will act as a single
entry point for requests. The Ingress Controller listens on the node's IP and 80/TCP port, and redirects requests to one cluster or the other depending on the services present in the path of the URI.


## TL;DR
```bash
helm install --name=nginx-ingress-controller stable/nginx-ingress -f ingress-controller-values.yml
kubectl create namespace thredds
kubectl apply -f thredds_deployment.yml
kubectl apply -f thredds_service.yml
kubectl apply -f thredds_ingress.yml
kubectl apply -f horizPodAutoScaler.yml
```
## thredds-deployment.yaml
With the Deployment object you define the number of replicas and the port(s) the containers will be listening on. It uses the official [Unidata Docker container](https://hub.docker.com/r/unidata/thredds-docker/dockerfile) as the image for the containers.
There are two deployments in this scenarios, one for each THREDDS cluster defined (`data` and `catalog`).

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: thredds-catalog
  namespace: thredds
spec:
  selector:
    matchLabels:
      app: thredds
      cluster: catalog
  replicas: 2
  template:
    metadata:
      labels:
        app: thredds
        cluster: catalog
    spec:
      containers:
        - name: thredds-catalog
          image: unidata/thredds-docker
          ports:
            - containerPort: 8080
          resources:
            requests:
              cpu: "200m"
              memory: "2Gi"

---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: thredds-data
  namespace: thredds
spec:
  selector:
    matchLabels:
      app: thredds
      cluster: data
  replicas: 2
  template:
    metadata:
      labels:
        app: thredds
        cluster: data
    spec:
      containers:
        - name: thredds-data
          image: unidata/thredds-docker
          ports:
            - containerPort: 8080
          resources:
            requests:
              cpu: "200m"
              memory: "2Gi"
```

## thredds\_service.yaml

There are two services configured, that serve the Pods of each cluster. As there is an Ingress Controller listening for outside requests, these services just need to be `ClusterIP`, accessible only inside the Kubernetes Cluster.

```yaml
apiVersion: v1
kind: Service
metadata:
  name: thredds-data
  namespace: thredds
spec:
  selector:
    app: thredds
    cluster: data
  type: ClusterIP
  ports:
    - protocol: TCP
      port: 8080

---
apiVersion: v1
kind: Service
metadata:
  name: thredds-catalog
  namespace: thredds
spec:
  selector:
    app: thredds
    cluster: catalog
  type: ClusterIP
  ports:
    - protocol: TCP
      port: 8080
```

## thredds\_ingress.yml
The Ingress element acts as the backend of the Ingress Controller. In this case two ingresses are defined, so the Ingress controller redirects to the corresponding service (and therefore, to the corresponding Pod) discriminating the path of the URI.

```yaml
apiVersion: extensions/v1beta1
kind: Ingress
metadata:
  labels:
    app: thredds
    cluster: data
    component: ingress
  name: thredds-data
  namespace: thredds
spec:
  rules:
  - host: thredds.<Access IP>.nip.io
    http:
      paths:
      - backend:
          serviceName: thredds-catalog
          servicePort: 8080
        path: /thredds/catalog

---
apiVersion: extensions/v1beta1
kind: Ingress
metadata:
  labels:
    app: thredds
    cluster: data
    component: ingress
  name: thredds-data
  namespace: thredds
spec:
  rules:
  - host: thredds.<Access IP>.nip.io
    http:
      paths:
      - backend:
          serviceName: thredds-data
          servicePort: 8080
        path: /thredds/dodsC
      - backend:
          serviceName: thredds-data
          servicePort: 8080
        path: /thredds/fileServer
      - backend:
          serviceName: thredds-data
          servicePort: 8080
        path: /thredds/dap4
      - backend:
          serviceName: thredds-data
          servicePort: 8080
        path: /thredds/ncss
```

## horizPodAutoscaler.yml
HPA checks for configured metric values at a default 30 second interval and tries to increase the number of replicas inside the deployment if the scecified threshold is met (with 10% tolerance). In this case the two THREDDS clusters are treated separately for monitoring and scaling.

```yaml
apiVersion: autoscaling/v1
kind: HorizontalPodAutoscaler
metadata:
  name: thredds-data-hpa
  namespace: thredds
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: thredds-data
  minReplicas: 2
  maxReplicas: 6
  targetCPUUtilizationPercentage: 50

---
apiVersion: autoscaling/v1
kind: HorizontalPodAutoscaler
metadata:
  name: thredds-catalog-hpa
  namespace: thredds
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: thredds-catalog
  minReplicas: 2
  maxReplicas: 6
  targetCPUUtilizationPercentage: 50

```

## References
* [Ingress - Kubernetes Docs](https://kubernetes.io/docs/concepts/services-networking/ingress/)
* [Ingress Controllers](https://kubernetes.io/docs/concepts/services-networking/ingress-controllers/)
* [Horizontal Pod Autoscaler - Kubernetes Docs](https://kubernetes.io/docs/tasks/run-application/horizontal-pod-autoscale/#support-for-cooldown-delay)

