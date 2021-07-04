# local-dev-cluster

A cluster to run locally with istio, knative, mongodb, postgres operator, and hasura.

Intended for developing cloud native microservices with CQRS/ES.

## Pre-setup

You might need to install some applications to build this correctly

```
brew install kind

brew install helm
helm repo add bitnami https://charts.bitnami.com/bitnami

brew tap knative/client
brew install kn

curl -L https://istio.io/downloadIstio | sh -
cd istio-1.10.0
export PATH=$PWD/bin:$PATH
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

## Destroy cluster

To delete your local-dev-cluster, run `make delete-cluster`