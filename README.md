# stratos-metrics

Stratos Metrics provides a Helm chart for deploying Prometheus and the Cloud Foundry Firehose exporter to Kubernetes.

It deploys both of these components and fronts the Prometheus server with an nginx server to provide authenticated access to Prometheus (currently basic authentication over https).

It also contains an initialization script that will setup a user in the UAA that has correct scopes/permissions to be able to read data from the firehose.

Lastly, the Helm chart generates a small metadata file in the root of the nginx server which is used by Stratos to determine which Cloud Foundry the Prometheus server is providing Metrics for.

## Installation

The Helm chart is published to the Stratos Helm repository.

Ensure you've followed the Stratos requirements for deploying to Kubernetes - https://github.com/SUSE/stratos/tree/master/deploy/kubernetes#requirements.

You will need to have the Stratos Helm repository added to your Helm setup, if you do not, run:

```
helm repo add stratos https://cloudfoundry-incubator.github.io/stratos
```

You may need to refresh from this repository, if you already had it added, by running:

```
helm repo update
```

You should see the metrics chart is available when running:

```
helm search metrics -l
```

You can install with:

```
helm install stratos/metrics --devel --namespace=metrics -f <CONFIG_VALUES>.yaml
```

Where `<CONFIG_VALUES>.yaml` is the name of a configuration values file that you must create (see below).

Note, if you are using SUSE Cloud Foundry, you can use your `scf_config_values.yaml` file that you used when deploying it.

This will create a Stratos Metrics instance in a namespace called `metrics` in your Kubernetes cluster.

If you want to use a Load Balancer or change the external IP, see the [Advanced Topics](#advanced-topics) section below.

## Configuration

You must create a yaml configuration file in order to deploy Stratos Metrics. An example is shown below:

```
nginx:
  externalIP: OPTIONAL
firehoseExporter:
  dopplerUrl: REQUIRED (e.g. wss://doppler.DOMAIN:4443)
  uaa:
    endpoint: REQUIRED (e.g. uaa.DOMAIN:2793)
    skipSslVerification: "true"
    cfIdentityZone: REQUIRED (e.g. cf)
    admin:
      client: REQUIRED
      clientSecret: REQUIRED
useLb: OPTIONAL (default: false)
kube:
  external_metrics_port: OPTIONAL (default: 7443)

```

Minimally, you need to set:

- The Doppler URL for your Cloud Foundry
- The URL of your UAA
- The Identity Zone that your Cloud Foundry uses in your UAA
- Client and Client Secret for an admin user of your UAA (in order to configure a Firehose user)

## Advanced Topics
### Using a Load Balancer
If your Kubernetes deployment supports automatic configuration of a load balancer (e.g. Google Container Engine), specify the parameters `useLb=true` when installing.

```
helm install stratos/metrics --devel --namespace=metrics -f <CONFIG_VALUES>.yaml --set useLb=true
```

### Specifying an External IP

If the kubernetes cluster supports external IPs for services (see [ Service External IPs](https://kubernetes.io/docs/concepts/services-networking/service/#external-ips)), then the following arguments can be provided. In this following example the metrics server will be available at `https://192.168.100.100:6000`.

```
helm install stratos/metrics --devel --namespace=metrics -f <CONFIG_VALUES>.yaml --set nginx.externalIP=192.168.100.100 nginx.externalPort=6000
```

## Accessing Metrics

Once deployed, the Prometheus server should be accessible via https.

The default credentials are:

```
Username: metrics
Password: s3cr3t
```

These are the same credentials you would use when connecting a metrics endpoit to Stratos.

We recommend you do not use the defaults - they can be changed via the following helm chart values:

```
nginx:
  username: <USERNAME>
  password: <PASSWORD>

```

## To Use with PCF Dev
To setup `stratos/metrics` instance against [PCF Dev](), save the following to a file called `pcf.yaml`
```
enabled: true
env:
    CLUSTER_ADMIN_PASSWORD: admin
    UAA_CF_IDENTITY_ZONE: uaa
    DOMAIN: local.pcfdev.io
    UAA_ADMIN_CLIENT_SECRET: admin-client-secret
    UAA_HOST: uaa.local.pcfdev.io
    UAA_PORT: 443
    DOPPLER_PORT: 443
firehoseExporter:
    noIdentityZone: true
```

To deploy `stratos/metrics` helm chart:
```
$helm install stratos/metrics -f pcf.yaml --namespace stratos-metrics
```

## Enabling Kubernetes Monitoring
Stratos can display information about a registered Kubernetes endpoint. To see metrics (pod usage/node usage etc.) of the cluster, the `stratos/metrics` chart can be deployed to gather those metrics.

To enable kubernetes monitoring, the following configuration needs to be provided. In this example configuration, `$KUBE_SERVER_ADDRESS` should be the Kubernetes cluster server address. You can usually find this address from your `kubeconfig` under `cluster.server`.
Please note, that this URL should be the same as the URL of the Kubernetes cluster registered in Stratos.

```
kubernetes:
  authEndpoint: $KUBE_SERVER_ADDRESS
prometheus:
  kubeStateMetrics:
    enabled: true
```

To deploy `stratos/metrics` helm chart:
```
$helm install stratos/metrics -f kube.yaml --namespace stratos-metrics
```

## Deploying Metrics in EKS

To deploy `stratos/metrics` in an EKS cluster, the following configuration overrides are required, save the following to `eks.yaml`:

```
useLb: true
kubernetes:
  authEndpoint: https://aaaaaa.sk1.us-east-1.eks.amazonaws.com // Your EKS endpoint address
prometheus:
  kubeStateMetrics:    
    enabled: true
```

Deploy `stratos/metrics` helm chart with the override:
```
$ helm install stratos/metrics -f eks.yaml --namespace eks-metrics
```

After deployment, fetch the external endpoint for the Metrics service.
```
11:04 $ kubectl get services --namespace eks-metrics                                                  
                                                                                                      

NAME                                        TYPE           CLUSTER-IP       EXTERNAL-IP               
                                              PORT(S)         AGE                                     
eks-metrics-metrics-nginx                   LoadBalancer   10.100.196.146   aaaa-759563135.us-east-1.elb.amazonaws.com   443:30241/TCP   39s                                     
eks-metrics-prometheus-kube-state-metrics   ClusterIP      None             <none>                    
                                              80/TCP          40s                                     
prometheus-service                          ClusterIP      10.100.135.21    <none>                    
                                              9090/TCP        40s                    
                                              ```
```
In this example, the metrics endpoint will be `https://aaaa-759563135.us-east-1.elb.amazonaws.com`

> **Note: If the pods are stuck in `pending` state, then there probably was an issue with the storage volumes. Create the approriate storage class and bind it to a specific zone to address the problem.
**

## Scaling Firehose Nozzles

You can scale the firehose nozzle in Stratos-Metrics by specifying the following override:
```
firehoseExporter:
  instances: 1
```

Please note, the number of firehose nozzles should be proportional to the number of Traffic Controllers in your Cloud Foundry ([see docs](https://docs.cloudfoundry.org/loggregator/log-ops-guide.html)). Otherwise, Loggregator will not split the firehose between the nozzles.

## Deploying Metrics from a Private Image Repository

If the images used by the chart are hosted in a private repository, the following needs to be specified. Save the following to a file called `private_overrides.yaml`. Replace `REGISTRY USER PASSSWORD`, `REGISTRY USERNAME`, `REGISTRY URL` with the appropriate values. `USER EMAIL` can be left blank.

```
prometheus:
  imagePullSecrets:
  - name: regsecret
kube:
  registry:
    password: <REGISTRY USER PASSWORD>
    username: <REGISTRY USERNAME>
    hostname: <REGISTRY URL>
    email: <USER EMAIL or leave blank>
```

To deploy `stratos/metrics` helm chart:
```
$helm install stratos/metrics -f private_overrides.yaml --namespace stratos-metrics
```
