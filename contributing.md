# Contributing guidelines

Contributions are welcome via GitHub pull requests. This document outlines the process to help get your contribution accepted.

## How to contribute

1. Fork this repository, develop, and test your changes.
1. Submit a pull request.

***NOTE***: In order to make testing and merging of PRs easier, please submit changes to multiple charts in separate PRs.

### Technical requirements

- Must follow [Charts best practices](https://helm.sh/docs/topics/chart_best_practices).
- Must pass CI jobs for linting and installing changed charts with the [chart-testing](https://github.com/helm/chart-testing) tool.
- Any change to a chart requires a version bump following [SemVer](https://semver.org) principles. See [immutability](#immutability) and [versioning](#versioning) below

Once changes have been merged, the release job will automatically run to package and release changed charts.

### Immutability

Chart releases must be immutable. Any change to a chart warrants a chart version bump even if it is only changed to the documentation.

### Versioning

The chart `version` should follow [SemVer](https://semver.org/).

Charts should start at `1.0.0`. Any breaking (backwards incompatible) changes to a chart should:

- Bump the **MAJOR** version.
- In the `readme.md` file, under a section called "Upgrade", describe the manual steps necessary to upgrade to the new (specified) **MAJOR** version

### Community requirements

This project is released with a [Contributor Covenant](https://www.contributor-covenant.org).

By participating in this project you agree to abide by its terms.
