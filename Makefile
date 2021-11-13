create-cluster:
	kind create cluster --name local-dev-cluster --config cluster.yaml
	kubectl ctx kind-local-dev-cluster

delete-cluster:
	kind delete clusters local-dev-cluster

deploy-examples:
	kn service create helloworld-go --image gcr.io/knative-samples/helloworld-go --env TARGET="Go Sample v1"
	kubectl apply -f ./examples/

delete-examples:
	kn service delete helloworld-go
	kubectl delete -f ./examples/

# updates in git
download-knative-operator:
	curl -L https://github.com/knative/operator/releases/download/v0.23.0/operator.yaml \
		| sed 's/namespace: default/namespace: knative-operator/' \
		> cluster-tooling/knative/operator-v0.23.0.yaml

finish-onboard:
	@echo "✅ Local Development Cluster Configured."
	@echo "👋 To use this cluster for development, in a new terminal, run \`make localizer\` and leave this process running to access internal Kubernetes addresses from your local machine."

install-cluster-tooling: install-metrics-server install-istio install-knative install-postgres-operator install-schemahero

install-hasura:
	kubectl apply -f cluster-tooling/hasura/postgresql.yaml
	sleep 10
	kubectl wait \
		--for=condition=ready pod \
		--selector=cluster-name=hasura-postgresql \
		--timeout=600s
	kubectl apply -f cluster-tooling/hasura/deployment.yaml
	kubectl apply -f cluster-tooling/hasura/service.yaml
	kubectl rollout status deployment -w hasura

install-istio:
	istioctl manifest apply --set profile=demo -y
	istioctl manifest generate --set profile=demo | istioctl verify-install -f -
	kubectl patch service istio-ingressgateway -n istio-system --patch "`cat cluster-tooling/istio/patch-ingressgateway-nodeport.yaml`"
	kubectl rollout status deployment -w -n istio-system istiod
	kubectl rollout status deployment -w -n istio-system istio-ingressgateway
	kubectl rollout status deployment -w -n istio-system istio-egressgateway

install-knative:
	-kubectl create ns knative-operator
	kubectl apply -f cluster-tooling/knative/operator-v0.23.0.yaml -n knative-operator
	kubectl rollout status deployment -w -n knative-operator knative-operator
	kubectl apply -f cluster-tooling/knative/knative-serving.yaml
	sleep 30
	kubectl rollout status deployment -w -n knative-serving activator
	kubectl rollout status deployment -w -n knative-serving autoscaler
	kubectl rollout status deployment -w -n knative-serving autoscaler-hpa
	kubectl rollout status deployment -w -n knative-serving controller
	kubectl rollout status deployment -w -n knative-serving istio-webhook
	kubectl rollout status deployment -w -n knative-serving networking-istio
	kubectl rollout status deployment -w -n knative-serving webhook
	kubectl label namespace default istio-injection=enabled --overwrite=true
	kubectl apply -f cluster-tooling/knative/knative-eventing.yaml
	sleep 30
	kubectl rollout status deployment -w -n knative-eventing eventing-controller
	kubectl rollout status deployment -w -n knative-eventing eventing-webhook
	kubectl rollout status deployment -w -n knative-eventing imc-controller
	kubectl rollout status deployment -w -n knative-eventing imc-dispatcher
	kubectl rollout status deployment -w -n knative-eventing mt-broker-controller
	kubectl rollout status deployment -w -n knative-eventing mt-broker-filter
	kubectl rollout status deployment -w -n knative-eventing mt-broker-ingress
	kubectl rollout status deployment -w -n knative-eventing pingsource-mt-adapter
	kubectl rollout status deployment -w -n knative-eventing sugar-controller

install-metrics-server:
	helm install metrics-server bitnami/metrics-server -n kube-system \
		-f cluster-tooling/metrics-server/values.yaml

install-postgres-operator:
	-kubectl create ns pgo
	helm install zalando zalando-pgo/postgres-operator -n pgo
	helm install zalando-ui zalando-pgo-ui/postgres-operator-ui -n pgo
	kubectl rollout status deployment -w -n pgo zalando-postgres-operator
	kubectl rollout status deployment -w -n pgo zalando-ui-postgres-operator-ui

install-schemahero:
	kubectl schemahero install

localizer:
	sudo localizer

onboard: create-cluster install-cluster-tooling finish-onboard