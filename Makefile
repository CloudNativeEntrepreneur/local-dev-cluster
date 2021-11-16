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
	curl -L https://github.com/knative/operator/releases/download/knative-v1.0.0/operator.yaml \
		| sed 's/namespace: default/namespace: knative-operator/' \
		> cluster-tooling/knative/operator-v1.0.0.yaml

download-olm:
	mkdir -p cluster-tooling/olm/charts/olm
	mkdir -p .tmp && cd .tmp && curl -L https://github.com/operator-framework/operator-lifecycle-manager/archive/v0.19.1.tar.gz | tar zx
	mv .tmp/operator-lifecycle-manager-0.19.1/deploy/chart/* cluster-tooling/olm/charts/olm

finish-onboard:
	@echo "✅ Local Development Cluster Configured."
	@echo "👋 To use this cluster for development, in a new terminal, run \`make localizer\` and leave this process running to access internal Kubernetes addresses from your local machine."

install-cluster-tooling: install-metrics-server install-olm install-istio install-knative install-postgres-operator install-schemahero

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

install-keycloak-operator:
	-kubectl create ns auth
	helm template cluster-tooling/auth/charts/keycloak-operator | kubectl apply -n auth -f -
	sleep 30
	kubectl rollout status deployment -n auth -w keycloak-operator

install-keycloak:
	helm template cluster-tooling/auth/charts/keycloak | kubectl apply -n auth -f -
	sleep 30
	kubectl rollout status deployment -n auth -w keycloak-postgresql
	kubectl rollout status statefulset -n auth -w keycloak

install-knative:
	-kubectl create ns knative-operator
	kubectl apply -f cluster-tooling/knative/operator-v1.0.0.yaml -n knative-operator
	kubectl rollout status deployment -w -n knative-operator knative-operator
	kubectl apply -f cluster-tooling/knative/knative-serving.yaml
	sleep 30
	kubectl rollout status deployment -w -n knative-serving activator
	kubectl rollout status deployment -w -n knative-serving autoscaler
	kubectl rollout status deployment -w -n knative-serving autoscaler-hpa
	kubectl rollout status deployment -w -n knative-serving controller
	kubectl rollout status deployment -w -n knative-serving domain-mapping
	kubectl rollout status deployment -w -n knative-serving domainmapping-webhook
	kubectl rollout status deployment -w -n knative-serving net-istio-webhook
	kubectl rollout status deployment -w -n knative-serving net-istio-controller
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
	kubectl rollout status deployment -w -n knative-eventing sugar-controller

install-metrics-server:
	helm install metrics-server bitnami/metrics-server -n kube-system \
		-f cluster-tooling/metrics-server/values.yaml
	kubectl rollout status -n kube-system -w deployment metrics-server

install-olm:
	kubectl apply -f cluster-tooling/olm/charts/olm/crds/
	helm template ./cluster-tooling/olm/charts/olm | kubectl apply -f -
	kubectl rollout status -n operator-lifecycle-manager -w deployment olm-operator
	kubectl rollout status -n operator-lifecycle-manager -w deployment catalog-operator

install-postgres-operator:
	-kubectl create ns pgo
	helm install zalando zalando-pgo/postgres-operator -n pgo
	helm install zalando-ui zalando-pgo-ui/postgres-operator-ui -n pgo
	kubectl rollout status deployment -w -n pgo zalando-postgres-operator
	kubectl rollout status deployment -w -n pgo zalando-ui-postgres-operator-ui

install-schemahero:
	kubectl schemahero install
	kubectl rollout status statefulset -n schemahero-system -w schemahero 

localizer:
	sudo localizer

onboard: create-cluster install-cluster-tooling finish-onboard