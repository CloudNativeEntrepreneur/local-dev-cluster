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

The local development cluster comes with Keycloak Operator installed via OLM, and a Keycloak instance and "dev" realm preconfigured.

Keycloak can be accessed at http://auth.127.0.0.1.sslip.io/

You can find the admin username and password with:

```
kubectl get secret -n auth credential-auth -o yaml | ksd
```

## Destroy cluster

To delete your local-dev-cluster, run `make delete-cluster`
