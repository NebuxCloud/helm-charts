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

- 🫧 **Workloads.** Define multiple workloads using [deployments](https://kubernetes.io/docs/concepts/workloads/controllers/deployment/) and [cron jobs](https://kubernetes.io/docs/concepts/workloads/controllers/cron-jobs/), supporting all kinds of containers ([init](https://kubernetes.io/docs/concepts/workloads/pods/init-containers/), [sidecar](https://kubernetes.io/docs/concepts/workloads/pods/sidecar-containers/) and main), startup/readiness/liveness probes, resource requests/limits, and volumes, among others.
- ♟️ **Deployment strategies.** Deploy changes with a blue-green strategy (non-native in Kubernetes) as well as the native ones (rolling and recreate).
- 📜 **Configuration.** Inject [config maps](https://kubernetes.io/docs/concepts/configuration/configmap/) and [secrets](https://kubernetes.io/docs/concepts/configuration/secret/) as environment variables, or mount them with [volumes](https://kubernetes.io/docs/concepts/storage/volumes/).
- 🪜 **Scaling.** Scale workloads with [horizontal pod autoscaling](https://kubernetes.io/docs/tasks/run-application/horizontal-pod-autoscale-walkthrough/).
- 🌍 **Ingress/gateway.** Expose your workloads' services using the [Ingress](https://kubernetes.io/docs/concepts/services-networking/ingress/) and the [Gateway](https://gateway-api.sigs.k8s.io/) APIs.
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
  oci://registry.nebux.dev/charts/generic \
  --version <x.y.z> \
  -f values.yml
```

### In CI/CD pipeline

#### Rolling

```console
helm upgrade --install \
    "<name>" \
    oci://registry.nebux.dev/charts/generic \
    --version <x.y.z> \
    --set-string "workloads.default.containers.default.image=<image>" \
    -f values.yml
```

#### Blue-green

```console
SLOT_PAST=$(kubectl get "svc/<name>" -o jsonpath='{.spec.selector.app\.kubernetes\.io/slot}')
SLOT_PAST=${SLOT_PAST:-green}
SLOT_CURRENT=$([ "${SLOT_PAST}" = 'blue' ] && echo -n 'green' || echo -n 'blue')


IMAGE_CURRENT="<image>"
IMAGE_PAST=$(kubectl get "deployment/<name>-${SLOT_PAST}" -o=jsonpath='{$.spec.template.spec.containers[:1].image}')
IMAGE_PAST=${IMAGE_PAST:-$IMAGE_CURRENT}

REPLICAS_PAST=$(kubectl get "deployment/<name>-${SLOT_PAST}" -o=jsonpath='{$.spec.replicas}')
REPLICAS_PAST=${REPLICAS_PAST:-1}
REPLICAS_CURRENT=$(kubectl get "deployment/<name>-${SLOT_PAST}" -o=jsonpath='{$.status.replicas}')
REPLICAS_CURRENT=${REPLICAS_CURRENT:-1}

helm upgrade --install \
    "<name>" \
    oci://registry.nebux.dev/charts/generic \
    --set-string "workloads.default.strategy.blueGreenUpdate.currentSlot=${SLOT_CURRENT}" \
    --set-string "workloads.default.strategy.blueGreenUpdate.targetSlot=${SLOT_PAST}" \
    --set-string "workloads.default.strategy.blueGreenUpdate.pastReplicas=${REPLICAS_PAST}" \
    --set-string "workloads.default.strategy.blueGreenUpdate.currentReplicas=${REPLICAS_CURRENT}" \
    --set-string "workloads.default.containers.default.image.${SLOT_PAST}=${IMAGE_PAST}" \
    --set-string "workloads.default.containers.default.image.${SLOT_CURRENT}=${IMAGE_CURRENT}" \
    -f values.yml

kubectl rollout status "deployment/<name>-${SLOT_CURRENT}" -w

helm upgrade \
    "<name>" \
    oci://registry.nebux.dev/charts/generic \
    --set-string "workloads.default.strategy.blueGreenUpdate.targetSlot=${SLOT_CURRENT}" \
    --reuse-values
```

## Configuration examples

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
            - default
          secrets:
            - default
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

### Blue-green

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
