# Nebux Kubernetes Helm Charts

![License](https://img.shields.io/github/license/NebuxCloud/helm-charts) ![Release Charts](https://github.com/NebuxCloud/helm-charts/actions/workflows/release.yml/badge.svg?branch=main) [![Releases downloads](https://img.shields.io/github/downloads/NebuxCloud/helm-charts/total.svg)](https://github.com/NebuxCloud/helm-charts/releases)

This repository contains the public Kubernetes Helm charts created and maintained by [Nebux](https://nebux.cloud).

## Usage

[Helm](https://helm.sh) must be installed to use the charts.
Please refer to Helm's [documentation](https://helm.sh/docs/) to get started.

Charts can be consumed from Nebux' OCI registry as follows:

```console
helm install <release-name> oci://registry.nebux.dev/charts/<chart-name> --version <x.y.z>
```

## Contributing

We'd love to have you contribute! Please refer to our [contribution guidelines](contributing.md) for details.

## License

[GNU General Public License v3.0](license.md)

## Helm charts build status

![Release Charts](https://github.com/NebuxCloud/helm-charts/actions/workflows/release.yaml/badge.svg?branch=main)
