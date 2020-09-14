# Change Log

## 1.3.0

[Full Changelog](https://github.com/SUSE/stratos-metrics/compare/1.2.1...1.3.0)

This release contains a number of fixes and improvements:

**Improvements:**

- Bump Prometheus Node Exporter to version 1.0.1 [\#70](https://github.com/SUSE/stratos-metrics/issues/70)
- Bump Kube State Metrics Exporter to version 1.9.7 [\#69](https://github.com/SUSE/stratos-metrics/issues/69)
- Bump CF Exporter to version 0.10.0 [\#68](https://github.com/SUSE/stratos-metrics/issues/68)
- Bump CF Firehose exporter to version 6.1.0 [\#67](https://github.com/SUSE/stratos-metrics/issues/67)
- Bump Prometheus version to 2.20.1 and Helm Chart Version 11.15.0 [\#66](https://github.com/SUSE/stratos-metrics/issues/66)

**Fixes:**

- Firehose exporter can sometimes stop ingesting metrics [\#73](https://github.com/SUSE/stratos-metrics/issues/73)


## 1.2.1

This release contains the following fix:

- Default metrics self-signed certificate is out of date [\#58](https://github.com/SUSE/stratos-metrics/issues/58)

## 1.2.0

This release contains the following fixes and updates:

- Add support for ingress [\#46](https://github.com/SUSE/stratos-metrics/issues/46)
- Kube State Metrics does not work with Kubernetes 1.16+ [\#47](https://github.com/SUSE/stratos-metrics/issues/47)
- Bump base image OS to newer Leap15_1/SLE 15 SP1 [\#48](https://github.com/SUSE/stratos-metrics/issues/48)
- Nginx pod crash loop backoff when domain name is not cluster.local [\#53](https://github.com/SUSE/stratos-metrics/issues/53)

## 1.1.2

This release contains one fix:

- Fix for metrics failing to deploy on kube 1.16+ [\#44](https://github.com/SUSE/stratos-metrics/pull/44)

## 1.1.1

This release contains one fix:

- Deploying Metrics on AKS is failing [\#40](https://github.com/SUSE/stratos-metrics/issues/42)

## 1.1.0

This release contains several new features and improvements, notably:

- Support for the Cloud Foundry Exporter
- Improved service configuration that adopts a more standard approach and consistency with Stratos
- Improved UAA configuration and creation of UAA clients for the Firehose Exporter
- Numerous tidy-ups to the values.yaml file
- Improved README
- Addition of an icon to the Helm Chart
- Fix: Clear text username/pwds are being displayed when describing a stratos metrics pod [\#40](https://github.com/SUSE/stratos-metrics/issues/40)

## 1.0.0

Initial release
