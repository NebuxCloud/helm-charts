<p align="center">
    <a href="https://nebux.cloud">
        <picture>
            <source media="(prefers-color-scheme: dark)" srcset="https://nebux.cloud/assets/brand/imagotype_light.svg">
            <img alt="Nebux logo" src="https://nebux.cloud/assets/brand/imagotype_dark.svg" height="60px">
        </picture>
    </a>
</p>

# Nebux Generic Helm Chart

This Helm chart allows orchestrating generic workloads with Kubernetes, reducing the complexity of its API for the most common cases and avoiding the need to create and maintain a chart for each project.

## Features

- 🫧 **Workloads.** Define multiple workloads using [deployments](https://kubernetes.io/docs/concepts/workloads/controllers/deployment/), [stateful sets](https://kubernetes.io/docs/concepts/workloads/controllers/statefulset/), [jobs](https://kubernetes.io/docs/concepts/workloads/controllers/job/) and [cron jobs](https://kubernetes.io/docs/concepts/workloads/controllers/cron-jobs/); supporting all kinds of containers ([init](https://kubernetes.io/docs/concepts/workloads/pods/init-containers/), [sidecar](https://kubernetes.io/docs/concepts/workloads/pods/sidecar-containers/) and main), startup/readiness/liveness probes, resource requests/limits, and volumes, among others.
- 🪝 **Lifecycle hooks.** Run one-shot [jobs](https://kubernetes.io/docs/concepts/workloads/controllers/job/) as [Helm hooks](https://helm.sh/docs/topics/charts_hooks/) (e.g. a database migration that must complete before the workloads roll out).
- ♟️ **Deployment strategies.** Deploy changes with a blue-green strategy (non-native in Kubernetes) as well as the native ones (rolling and recreate).
- 📜 **Configuration.** Inject [config maps](https://kubernetes.io/docs/concepts/configuration/configmap/) and [secrets](https://kubernetes.io/docs/concepts/configuration/secret/) as environment variables, or mount them with [volumes](https://kubernetes.io/docs/concepts/storage/volumes/).
- 💾 **Persistence.** Store persistent data from workloads with [persistent volume claims](https://kubernetes.io/docs/concepts/storage/persistent-volumes/).
- 🪜 **Scaling.** Scale workloads with [horizontal pod autoscaling](https://kubernetes.io/docs/tasks/run-application/horizontal-pod-autoscale-walkthrough/).
- 🌍 **Ingress/gateway.** Expose your workloads' services using the [Ingress](https://kubernetes.io/docs/concepts/services-networking/ingress/) and the [Gateway](https://gateway-api.sigs.k8s.io/) APIs, with HTTP, TCP and UDP routes.
- 🔒 **Security.** Secure your workloads with [network policies](https://kubernetes.io/docs/concepts/services-networking/network-policies/) and [security contexts](https://kubernetes.io/docs/tasks/configure-pod-container/security-context/) (at pod and container levels).
- ❤️‍🩹 **Resilience.** Maximize availability with [pod disruption budgets](https://kubernetes.io/docs/tasks/run-application/configure-pdb/).
- 🪪 **RBAC.** Full [RBAC](https://kubernetes.io/docs/reference/access-authn-authz/rbac/) support with [service accounts](https://kubernetes.io/docs/concepts/security/service-accounts/), roles and bindings (at namespace and cluster level).
- ⚖️ **FOSS.** Completely free and open-source under the GPL-3.0 license.

## Usage

This chart is designed to deploy any workload with a short and easy-to-read values file (see examples below).

Please check [the example values](values.yaml) to see all supported parameters. You can also find a real-life use case [here](https://github.com/NebuxCloud/botbuster?tab=readme-ov-file#helm).

### Manual

```console
helm install \
  <name> \
  oci://registry.nebux.dev/charts/nebux-generic \
  --version <x.y.z> \
  -f values.yml
```

### In CI/CD pipeline

#### Rolling

```console
helm upgrade --install \
    "<name>" \
    oci://registry.nebux.dev/charts/nebux-generic \
    --version <x.y.z> \
    --set-string "workloads.default.containers.default.image=<image>" \
    -f values.yml
```

#### Blue-green

The rollout state (which slot is live, which one is being deployed to, and
their replica counts) lives in the release values and is injected by the pipeline
on every deployment. The slot the `Service` currently routes to is the
source of truth, and any failure reading it aborts it.

Deployments of the same release must be serialized (e.g. with a CI concurrency
group): two of these scripts racing each other read and write the same slot
state.

In the chart values, `targetSlot` is the slot the `Service` routes to *right
now*, and `currentSlot` is the slot holding the *newest* code — so a rollout is
in progress whenever they differ.

```console
set -euo pipefail

name='<name>'                                          # release name
namespace='<namespace>'
context='<environment>'                                # selects values.<environment>.yml
chart='oci://registry.nebux.dev/charts/nebux-generic'
chart_version='<x.y.z>'
values_dir='<values directory>'
image='<image>'                                        # repository, without the tag
tag='<tag>'

IMAGE_NEW="${image}:${tag}"

SLOT_LIVE=$(kubectl get "svc/${name}" -n "${namespace}" -o jsonpath='{.spec.selector.app\.kubernetes\.io/slot}' 2>&1) ||
  { [[ "${SLOT_LIVE}" == *NotFound* ]] && SLOT_LIVE=''; } ||
  { echo "Cannot read svc/${name}: ${SLOT_LIVE}" >&2; exit 1; }

case "${SLOT_LIVE}" in
  blue|green)
    SLOT_NEW=$([ "${SLOT_LIVE}" = 'blue' ] && echo -n 'green' || echo -n 'blue')
    LIVE=$(kubectl get "deployment/${name}-${SLOT_LIVE}" -n "${namespace}" -o json)
    IMAGE_LIVE=$(jq -er '.spec.template.spec.containers[] | select(.name == "default").image' <<< "${LIVE}")
    REPLICAS_LIVE=$(jq -r '.spec.replicas // 1' <<< "${LIVE}")
    REPLICAS_NEW=$(jq -r '.status.replicas // 1' <<< "${LIVE}")
    ;;
  '')
    SLOT_LIVE='green'
    SLOT_NEW='blue'
    IMAGE_LIVE="${IMAGE_NEW}"
    REPLICAS_LIVE='1'
    REPLICAS_NEW='1'
    ;;
  *)
    echo "Unexpected slot '${SLOT_LIVE}' on svc/${name}; aborting." >&2
    exit 1
    ;;
esac

helm upgrade --install "${name}" "${chart}" \
  --version "${chart_version}" \
  --namespace "${namespace}" \
  --force-conflicts \
  --set-string "workloads.default.strategy.blueGreenUpdate.currentSlot=${SLOT_NEW}" \
  --set-string "workloads.default.strategy.blueGreenUpdate.targetSlot=${SLOT_LIVE}" \
  --set-string "workloads.default.strategy.blueGreenUpdate.pastReplicas=${REPLICAS_LIVE}" \
  --set-string "workloads.default.strategy.blueGreenUpdate.currentReplicas=${REPLICAS_NEW}" \
  --set-string "workloads.default.containers.default.image.${SLOT_LIVE}=${IMAGE_LIVE}" \
  --set-string "workloads.default.containers.default.image.${SLOT_NEW}=${IMAGE_NEW}" \
  -f "${values_dir}/values.yml" \
  -f "${values_dir}/values.${context}.yml"

kubectl scale "deployment/${name}-${SLOT_NEW}" -n "${namespace}" --replicas="${REPLICAS_NEW}"

kubectl rollout status "deployment/${name}-${SLOT_NEW}" -n "${namespace}" --timeout=10m ||
  { helm rollback "${name}" -n "${namespace}" ||
    kubectl scale "deployment/${name}-${SLOT_NEW}" -n "${namespace}" --replicas=0; exit 1; }

helm upgrade "${name}" "${chart}" \
  --version "${chart_version}" \
  --namespace "${namespace}" \
  --force-conflicts \
  --set-string "workloads.default.strategy.blueGreenUpdate.targetSlot=${SLOT_NEW}" \
  --reuse-values
```

## Configuration examples

### Referencing resources

Every reference to another resource — config maps and secrets (via `volumes`,
`envFrom` or `env` `valueFrom`), service names, service accounts, image pull
secrets, RBAC roles/bindings, HTTP/TCP/UDP route backends, an ingress' service and its
`tlsSecretName`, etc. — follows the same `@` convention:

- `@name` is **release-managed**: the release name is prepended (`@name` →
  `<release>-name`, and a bare `@` → `<release>`).
- Any other value is used **verbatim**, so you can reference resources outside
  this release (created by another release, an operator such as
  [External Secrets](https://external-secrets.io/), etc.).

Config maps and secrets are a special case: as they are auto-named after the
release, the key is only appended when more than one is defined (`@foo` →
`<release>` with a single secret, or `<release>-foo` with several).

```yaml
workloads:
  default:
    containers:
      default:
        image: registry.nebux.dev/my-fancy-api:v0.0.0
        envFrom:
          secrets:
            - "@default"         # release-managed secret
            - shared-credentials # external secret, used as-is

    volumes:
      - name: app-config
        configMap:
          name: "@default" # release-managed config map

      - name: tls
        secret:
          secretName: certificate-example-org  # external secret, used as-is
```

### Rolling release

```yaml
workloads:
  default:
    revisionHistoryLimit: 10

    strategy:
      rollingUpdate:
        maxUnavailable: 1
        maxSurge: 1

    containers:
      default:
        image: registry.nebux.dev/my-fancy-api:v0.0.0
        command:
          - api
        args:
          - --port=3000
        envFrom:
          configMaps:
            - "@default"
          secrets:
            - "@default"
        resources:
          requests:
            cpu: 50m
            memory: 64Mi
          limits:
            cpu: 100m
            memory: 256Mi
        ports:
          - name: http
            containerPort: 3000
        probes:
          readiness:
            httpGet:
              path: /_health
              port: http
            initialDelaySeconds: 5
          liveness:
            httpGet:
              path: /_health
              port: http
            initialDelaySeconds: 5

    imagePullSecrets:
    - name: registry

    autoscaling:
      targetCPUUtilizationPercentage: 90
      replicas:
        min: 2
        max: 6

    disruptionBudget:
      maxUnavailable: 1

    networkPolicy:
      ingress:
        - ports:
            - port: http
          from:
            - namespaceSelector:
                matchLabels:
                  kubernetes.io/metadata.name: another-namespace
            - podSelector:
                matchLabels:
                  app.kubernetes.io/instance: consumer-software

    service:
      annotations:
        service.kubernetes.io/topology-mode: Auto
      type: ClusterIP
      ports:
        - name: http
          port: 80
          targetPort: http

configMaps:
  default:
    FOO: "bar"

# Don't add secrets here in version-controlled files, as they would be exposed!
# This object should only contain empty keys for documentation purposes.
secrets:
  default: {}
    #SUPER_SECRET: proto://my-fancy-software:<password>@service:1234
```

### Blue-green release

The values file only *enables* the strategy: the rollout state (`currentSlot`,
`targetSlot` and the replica counts) is injected by the deployment pipeline
(see above). The chart refuses to render without it, so an upgrade outside the
pipeline (e.g. a manual config change) must pass `--reuse-values` to preserve
the state — otherwise both slots would be reset.

```yaml
workloads:
  default:
    revisionHistoryLimit: 10

    strategy:
      blueGreenUpdate: {}

    containers:
      default:
        image: registry.nebux.dev/my-fancy-web:v0.0.0
        resources:
          requests:
            cpu: 100m
            memory: 128Mi
          limits:
            cpu: "1"
            memory: 512Mi
        ports:
          - name: http
            containerPort: 3000
        probes:
          readiness:
            httpGet:
              path: /
              port: http
            initialDelaySeconds: 10
          liveness:
            httpGet:
              path: /
              port: http
            initialDelaySeconds: 10

    imagePullSecrets:
      - name: registry

    autoscaling:
      targetCPUUtilizationPercentage: 90
      replicas:
        min: 2
        max: 6

    disruptionBudget:
      maxUnavailable: 1

    networkPolicy:
      ingress:
        - ports:
            - port: http
          from:
            - namespaceSelector:
                matchLabels:
                  kubernetes.io/metadata.name: networking
            - podSelector:
                matchLabels:
                  app.kubernetes.io/instance: ingress-controller

    service:
      annotations:
        service.kubernetes.io/topology-mode: Auto
      type: ClusterIP
      ports:
        - name: http
          port: 80
          targetPort: http
```

### Database migration (pre-rollout Job hook)

Run a migration once per install/upgrade, ordered **before** the workloads roll
out, by declaring a Job with `helmHooks`. `post-install,pre-upgrade` guarantees
the release-managed secret it reads already exists (created on install, and the
previous revision's copy on upgrade). If the migration fails, the upgrade is
aborted before any new pod starts.

```yaml
jobs:
  migrate:
    helmHooks:
      events: [post-install, pre-upgrade]
      weight: -5 # run before other hooks
      deletePolicy: [before-hook-creation, hook-succeeded]
    backoffLimit: 3
    activeDeadlineSeconds: 900
    ttlSecondsAfterFinished: 300
    containers:
      default:
        image: registry.nebux.dev/my-fancy-api:v0.0.0
        command:
          - ./bin
          - database:migrate
        envFrom:
          configMaps:
            - "@default"
          secrets:
            - "@default"

workloads:
  default:
    containers:
      default:
        image: registry.nebux.dev/my-fancy-api:v0.0.0
        # ...
```
