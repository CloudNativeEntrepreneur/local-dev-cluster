# local-development-cluster

A cluster to run locally with istio, knative, postgres operator, schemahero, keycloak, and other local dev tooling.

## Pre-setup

You will need to install some tools locally:

* K-in-D (Kubernetes in Docker)
* Helm
* KNative
* Istio
* Krew
* SchemaHero

The repository [onboard](https://github.com/cloudnativeentrepreneur/onboard) attempts to install all of these in an automated fashion.

### Helm Repos

You may need to add the following helm repos

```
helm repo add bitnami https://charts.bitnami.com/bitnami
helm repo add zalando-pgo https://opensource.zalando.com/postgres-operator/charts/postgres-operator/
helm repo add zalando-pgo-ui https://opensource.zalando.com/postgres-operator/charts/postgres-operator-ui/
```

## Setup

```
make onboard
```

Your cluster will continue to exist until you delete it. You can stop docker, and restart docker, and your cluster will come back up where you left off.

## Examples

To deploy the examples, run:

```
make deploy-examples
```

### Example KNative Serving

If everything goes well, you should be able to curl the example knative service:

```
> kubectl get ksvc
NAME            URL                                               LATESTCREATED         LATESTREADY           READY   REASON
helloworld-go   http://helloworld-go.default.127.0.0.1.sslip.io   helloworld-go-00001   helloworld-go-00001   True
```

```
> curl http://helloworld-go.default.127.0.0.1.sslip.io
Hello Go Sample v1!
```

### Example KNative Eventing

KNative Eventing is installed with an InMemory Broker.

To test it, attach to the `curl` pod, and send some example events:

```
kubectl attach curl -it
```

Then, inside the pod, make the following requests:

```
curl -v "http://broker-ingress.knative-eventing.svc.cluster.local/default/default" \
  -X POST \
  -H "Ce-Id: say-hello" \
  -H "Ce-Specversion: 1.0" \
  -H "Ce-Type: greeting" \
  -H "Ce-Source: not-sendoff" \
  -H "Content-Type: application/json" \
  -d '{"msg":"Hello Knative!"}'
```

And:

```
curl -v "http://broker-ingress.knative-eventing.svc.cluster.local/default/default" \
  -X POST \
  -H "Ce-Id: say-goodbye" \
  -H "Ce-Specversion: 1.0" \
  -H "Ce-Type: not-greeting" \
  -H "Ce-Source: sendoff" \
  -H "Content-Type: application/json" \
  -d '{"msg":"Goodbye Knative!"}'
```

And:

```
curl -v "http://broker-ingress.knative-eventing.svc.cluster.local/default/default" \
  -X POST \
  -H "Ce-Id: say-hello-goodbye" \
  -H "Ce-Specversion: 1.0" \
  -H "Ce-Type: greeting" \
  -H "Ce-Source: sendoff" \
  -H "Content-Type: application/json" \
  -d '{"msg":"Hello Knative! Goodbye Knative!"}'
```

You can now `exit` the curl container, and check the logs to see the events were correctly received and processed:

```
exit
```

And then:

```
kubectl logs -l app=hello-display --tail=100 -c event-display
kubectl logs -l app=goodbye-display --tail=100 -c event-display
```

### Delete Examples

To delete the examples from your local cluster, run:

```
make delete-examples
```

## Authentication

The local development cluster comes with scripts to set up Keycloak Operator installed via OLM, and a Keycloak instance and "dev" realm preconfigured. These are not used in every project, and therefore not installed by default.

To install OLM, the keycloak operator, and keycloak, run `make install-keycloak`

Keycloak can be accessed at http://auth.127.0.0.1.sslip.io/

You can find the admin username and password with:

```
kubectl get secret -n auth credential-auth -o yaml | ksd
```

## Networking

To be able to use tools like schemahero, the postgres operator, and other cool things that are possible with Kubernetes, we need to run Kubernetes. The problem is these things are within a private network inside of kubernetes. For development that is not ideal.

When developing, it's easiest to have everything on `localhost` cause you can't just send requests across networks.

I've found a good blend is to run the "appliance" type things, like databases, or a 3rd-party helm chart or container you just run, are great to set up on Kubernetes, because they are easy to set up, but then they are hard to get at - so I use port-forwarding to expose those needed appliances to my local network, but I use `localizer` to do the port-forwarding. From within the kubernetes network, use `host.docker.internal`.

### host.docker.internal

Still, some appliance type applications are still complicated by this network division, such as Hasura's Actions feature - if it's running inside of Kubernetes it can't send requests to localhost. Luckily, at least when running Kubernetes with Kind (Kubernetes in Docker), as the local development cluster does, as well as some other local kubernetes clusters based on docker, we can access `localhost` via `host.docker.internal`

### localizer

Localizer eases development with Kubernetes by managing tunnels and host aliases to your connected Kubernetes cluster. This way, instead of port-forwarding tools like databases to use them, you can just use their internal network address: `http://${serviceName}.${namespace}.svc.cluster.local`.

This is kinda the opposite of host.docker.internal - it allows local services to hit services running inside of kubernetes.

It does this by managing the port-forwarding for you as well as updating you `/etc/hosts` file on your local machine with that port forward information.

For example, to connect to the `example-readmodel` psql db:

```
HASURA_GRAPHQL_METADATA_DATABASE_URL=postgres://metadata:$(kubectl get secret metadata.hasura-metadata-postgresql.credentials.postgresql.acid.zalan.do)@hasura-metadata-postgresql.default.svc.cluster.local:5432/metadata

HASURA_GRAPHQL_DATABASE_URL=postgres://readmodel:$(kubectl get secret readmodel.example-readmodel-postgresql.credentials.postgresql.acid.zalan.do)@example-readmodel-postgresql.default.svc.cluster.local:5432/readmodel
```

Will work from inside the cluster, as well as localhost with localizer.

## Destroy cluster

To delete your local-dev-cluster, run `make delete-cluster`
