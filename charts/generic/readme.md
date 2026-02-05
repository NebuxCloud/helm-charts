# Generic

This chart allows deploying generic workloads in Kubernetes (with as many deployments and as many containers per deployment as needed).

It is designed to fit most use cases with a consistent approach, and it supports both rolling and blue-green deployments.

Using this chart reduces the complexity of deploying multiple projects in Kubernetes and eliminates the need to create and maintain a chart for each one.

## Usage

### Manual

```console
helm install <name> oci://registry.nebux.dev/charts/generic --version <x.y.z>
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
