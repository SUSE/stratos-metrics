# Stratos Metrics

Stratos Metrics provides a Helm chart for deploying Prometheus and the following metrics exporters to Kubernetes:

- Cloud Foundry Firehose Exporter (enabled by default)
- Cloud Foundry Exporter (disabled by default)
- Kubernetes State Metrics Exporter (disabled by default)

The Stratos Metrics Helm Chart deploys a Prometheus server and the configured Exporters  and fronts the Prometheus server with an nginx server to provide authenticated access to Prometheus (currently basic authentication over https).

When required by configuration, it also contains an initialization script that will setup users in the UAA that have correct scopes/permissions to be able to read data from the Cloud Foundry Firehose and/or API.

Lastly, the Helm chart generates a small metadata file in the root of the nginx server which is used by Stratos to determine which Cloud Foundry and Kubernetes clusters the Prometheus server is providing Metrics for.

## Installation

The Helm chart is published to the Stratos Helm repository. Ensure you've followed the Stratos requirements for deploying to Kubernetes - https://github.com/SUSE/stratos/tree/master/deploy/kubernetes#requirements.

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
helm install stratos/metrics --namespace=metrics -f <CONFIG_VALUES>.yaml
```

Where `<CONFIG_VALUES>.yaml` is the name of a configuration values file that you must create (see below).

If you want to use a Load Balancer or change the external IP, see the [Advanced Topics](#advanced-topics) section below.

>Note, if you are using SUSE Cloud Foundry, you can use your `scf_config_values.yaml` file that you used when deploying it.

This will create a Stratos Metrics instance in a namespace called `metrics` in your Kubernetes cluster.

## Connecting Metrics to Stratos

Once deployed, the Prometheus server should be accessible via https, ready to connect to Stratos.

When connecting, the default credentials are:

```
Username: metrics
Password: s3cr3t
```

> NOTE: We recommend that you *do not* use the defaults - they can be changed via the following helm chart values:

```
metrics:
  username: <USERNAME>
  password: <PASSWORD>
```

# Exporter Configuration

## Firehose Exporter

This exporter can be enabled/disabled via the Helm value `firehoseExporter.enabled`. By default this exporter is enabled.

You must provide the following Helm Chart values for this Exporter to work correctly:

- `cloudFoundry.apiEndpoint` -  API Endpoint of the Cloud Foundry API Server 
- `cloudFoundry.uaaAdminClient` - Admin client of the UAA used by the Cloud Foundry server
- `cloudFoundry.uaaAdminClientSecret` - Admin client secret of the UAA used by the Cloud Foundry serve
- `cloudFoundry.skipSslVerification` - Whether to skip SSL verification when communicating with Cloud Foundry and the UAA APIs

You can scale the firehose nozzle in Stratos-Metrics by specifying the following override:
```
firehoseExporter:
  instances: 1
```

Please note, the number of firehose nozzles should be proportional to the number of Traffic Controllers in your Cloud Foundry ([see docs](https://docs.cloudfoundry.org/loggregator/log-ops-guide.html)). Otherwise, Loggregator will not split the firehose between the nozzles.

## Cloud Foundry Exporter

This exporter can be enabled/disabled via the Helm value `cfExporter.enabled`. By default this exporter is disabled.

You must provide the following Helm Chart values for this Exporter to work correctly:

- `cloudFoundry.apiEndpoint` -  API Endpoint of the Cloud Foundry API Server 
- `cloudFoundry.uaaAdminClient` - Admin client of the UAA used by the Cloud Foundry server
- `cloudFoundry.uaaAdminClientSecret` - Admin client secret of the UAA used by the Cloud Foundry serve
- `cloudFoundry.skipSslVerification` - Whether to skip SSL verification when communicating with Cloud Foundry and the UAA APIs

## Kubernetes Monitoring

This exporter can be enabled/disabled via the Helm value `prometheus.kubeStateMetrics.enabled`. By default this exporter is disabled. 

You must provide the following Helm Chart values for this Exporter to work correctly:

- `kubernetes.apiEndpoint` - The API Endpoint of the Kubernetes API Server

# Helm Chart Configuration

The following table lists the configurable parameters of the Metrics chart and their default values.

|Parameter|Description|Default|
|---|---|---|
|imagePullPolicy|Image pull policy|IfNotPresent|
|metrics.username|Basic Auth username for accessing metrics services|metrics|
|metrics.password|Basic Auth password for accessing metrics services_see values.yaml_||
|metrics.service.type|Type of the metrics service to create|ClusterIP||
|metrics.service.annotations|Annotations for the metrics service|[]|
|metrics.service.externalIPs|External IP addresses for the metrics service|[]|
|metrics.service.loadBalancerIP|IP address to assign to the load balancer for the metrics service (if supported)||
|metrics.service.loadBalancerSourceRanges|List of IP CIDRs allowed access to load balancer (if supported)|[]|
|metrics.service.servicePort|Service port for the metrics service|443|
|metrics.service.nodePort|Node port for the metrics service  (ignored if metrics.service.type is not NodePort)||
|metrics.service.externalName|External name for the metrics service||
|nginx.ssl.cert|TLS Certificate for the metrics service|_self-signed dev certificate_|
|nginx.ssl.key|TLS Private Key for the metrics service|_self-signed dev certificate_|
|cloudFoundry.apiEndpoint|API Endpoint of the Cloud Foundry API Server (required by the Firehose and CF Exporters)||
|cloudFoundry.uaaAdminClient|Admin client of the UAA used by the Cloud Foundry server (required by the Firehose and CF Exporters)|admin|
|cloudFoundry.uaaAdminClientSecret|Admin client secret of the UAA used by the Cloud Foundry server (required by the Firehose and CF Exporters)||
|cloudFoundry.skipSslVerification|Whether to skip SSL verification when communicating with Cloud Foundry and the UAA APIs|"true"|
|firehoseExporter.enabled|Flag to enable ot disable the Prometheus Firehose Exporter|true|
|firehoseExporter.instances|Number of instance of the firehose exporter to scale to|1|
|firehoseExporter.dopplerUrl|URL of the Cloud Foundry Doppler endpoint to monitor (used by the firehose exporter and takes precedence over specifying the Cloud Foundry API endpoint)||
|cfExporter.enabled|Flag to enable ot disable the Prometheus CF Exporter|false|
|kubernetes.apiEndpoint|URL of the Kubernetes API Server||
|prometheus.kubeStateMetrics.enabled|Enables the Kubernetes state metrics prometheus Exporter|false|
|kube.auth|Set to "rbac" if the Kubernetes cluster supports Role-based access control|"rbac"|
|prometheus.server.storageClass|Storage class to use for the Prometheus server|<none> (use default storage class)|


# Advanced Topics

## Using a Load Balancer

If your Kubernetes deployment supports automatic configuration of a load balancer (e.g. Google Container Engine), specify the parameters `metrics.service.type=LoadBalancer` when installing.

```
helm install stratos/metrics --devel --namespace=metrics -f <CONFIG_VALUES>.yaml --set metrics.service.type=LoadBalancer
```

## Specifying an External IP

If the Kubernetes cluster supports external IPs for services (see [Service External IPs](https://kubernetes.io/docs/concepts/services-networking/service/#external-ips)), then the following argument can be provided:

```
helm install stratos/metrics --devel --namespace=metrics -f <CONFIG_VALUES>.yaml --set metrics.service.externalIP=192.168.100.100
```

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
helm install stratos/metrics -f private_overrides.yaml --namespace=metrics
```

## Advanced Prometheus Configuration

Stratos Metrics uses the Prometheus Helm chart (https://github.com/helm/charts/tree/master/stable/prometheus) as a sub-chart.

You can override settings for Prometeus, as described in this sub-chart, but prefixing the value with `prometheus`. For example, `prometheus.server.storageClass` changes the storage class used by the Promethus server.
 
