namespace="monitoring"
namespace2="db"
# setup metricScraper

# 1 basic prometheus setup
kubectl create namespace $namespace
kubectl create -f ../ProvenanceEngine/MetricScraper/minimal_setup/clusterRole.yaml --namespace $namespace
kubectl create -f ../ProvenanceEngine/MetricScraper/minimal_setup/config-map.yaml --namespace $namespace
kubectl create -f ../ProvenanceEngine/MetricScraper/minimal_setup/prometheus-deployment.yaml --namespace $namespace
kubectl create -f ../ProvenanceEngine/MetricScraper/minimal_setup/prometheus-service.yaml --namespace $namespace

# 2 kube-state-metrics
kubectl apply -f ../ProvenanceEngine/MetricScraper/minimal_setup/kube-state-metrics

# 3 node-exporter
kubectl create -f ../ProvenanceEngine/MetricScraper/minimal_setup/node-exporter/daemonset.yaml
kubectl create -f ../ProvenanceEngine/MetricScraper/minimal_setup/node-exporter/service.yaml

echo "Prometheus setup completed"

# setup pgSQL & pgREST

kubectl create namespace $namespace2
kubectl apply -f ../ProvenanceEngine/database/pgSQL/db-volume-claim.yaml --namespace $namespace2
kubectl apply -f ../ProvenanceEngine/database/pgSQL/db-configmap.yaml --namespace $namespace2
kubectl apply -f ../ProvenanceEngine/database/pgSQL/db-deployment.yaml --namespace $namespace2
kubectl apply -f ../ProvenanceEngine/database/pgSQL/db-service.yaml --namespace $namespace2

kubectl apply -f ../ProvenanceEngine/database/pgREST/postgrest-deployment.yaml --namespace $namespace2
kubectl apply -f ../ProvenanceEngine/database/pgREST/postgrest-service.yaml --namespace $namespace2


#start prov collector
kubectl create -f ../ProvenanceEngine/ProvenanceCollector/deployment.yaml --namespace monitoring
sleep 20


# Get the name of the latest deployment in the namespace
latest_deployment=$(kubectl get deployment -n $namespace2 -o custom-columns=":metadata.name" --sort-by=.metadata.creationTimestamp | tail -n 1)

# Wait for the latest deployment to be ready
kubectl wait --for=condition=available deployment/$latest_deployment -n $namespace2

# Restart the latest deployment
kubectl rollout restart deployment/$latest_deployment -n $namespace2


echo -e "postGREST service and pods started \n"

sleep 3

#kill daemonset
kubectl delete daemonset sysbench-daemonset -n cws
