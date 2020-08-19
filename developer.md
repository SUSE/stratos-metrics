# Developer Documentation

Stratos Metrics is a Helm Chart for deploying Prometheus with:

- an nginx wrapper to provide Basic authentication
- the Cloud Foundry Firehose exporter
- the Cloud Foundry Exporter
- an init job that creates the necessary UAA client for the firehose exporter
- ingress support for the nginx wrapper

It uses Prometheus as a sub-chart. We build our own images using either Leap or SLE as the base OS.

The Prometheus sub-chart is currently taken from: https://kubernetes-charts.storage.googleapis.com

## Developer Build

Build scripts are in the `build` folder along with Dockerfiles for the images that are needed.

The main script is `build.sh`.

The build uses the Stratos base images - see: https://github.com/cloudfoundry/stratos/tree/master/deploy/stratos-base-images

## Release Build

Release images and Helm Chart are build using Concourse - pipelines and tasks are in the `build/ci` folder.

There are two main pipelines:

- create-release.yml - Makes a chart and images for an Alpha, Beta or RC
- promote-release.yml - Promotes an RC to a GM release

## Test

We use `helm-unittest` to create tests for the Helm Chart - see: https://github.com/lrills/helm-unittest