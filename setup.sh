#!/bin/bash
namespace="cws"
namespace2="db"

# setup of cws related stuff
kubectl create namespace $namespace
kubectl create namespace $namespace2
kubectl apply -f setup/pv.yaml --namespace $namespace
kubectl apply -f setup/pvc.yaml --namespace $namespace
kubectl apply -f setup/management.yaml --namespace $namespace
kubectl wait --for=condition=ready pod management --namespace $namespace

# setup metricScraper
# 1 basic prometheus setup
kubectl create namespace monitoring
kubectl create -f ../ProvenanceEngine/MetricScraper/minimal_setup/kubernetes-prometheus/clusterRole.yaml
kubectl create -f ../ProvenanceEngine/MetricScraper/minimal_setup/kubernetes-prometheus/config-map.yaml
kubectl create -f ../ProvenanceEngine/MetricScraper/minimal_setup/kubernetes-prometheus/prometheus-deployment.yaml

# 2 kube-state-metrics
kubectl apply -f ../ProvenanceEngine/MetricScraper/minimal_setup/kube-state-metrics

# 3 node-exporter
kubectl create -f ../ProvenanceEngine/MetricScraper/minimal_setup/node-exporter/daemonset.yaml
kubectl create -f ../ProvenanceEngine/MetricScraper/minimal_setup/node-exporter/service.yaml

# setup pgSQL & pgREST

kubectl apply -f ../ProvenanceEngine/database/pgSQL/db-persistent-volume.yaml --namespace $namespace2
kubectl apply -f ../ProvenanceEngine/database/pgSQL/db-volume-claim.yaml --namespace $namespace2
kubectl apply -f ../ProvenanceEngine/database/pgSQL/db-configmap.yaml --namespace $namespace2
kubectl apply -f ../ProvenanceEngine/database/pgSQL/db-deployment.yaml --namespace $namespace2
kubectl apply -f ../ProvenanceEngine/database/pgSQL/db-service.yaml --namespace $namespace2

#echo -e "------database service and pods started------\n"

kubectl apply -f ../ProvenanceEngine/database/pgREST/postgrest-deployment.yaml --namespace $namespace2
kubectl apply -f ../ProvenanceEngine/database/pgREST/postgrest-service.yaml --namespace $namespace2

# Get the name of the latest deployment in the namespace
latest_deployment=$(kubectl get deployment -n $namespace2 -o custom-columns=":metadata.name" --sort-by=.metadata.creationTimestamp | tail -n 1)

# Wait for the latest deployment to be ready
kubectl wait --for=condition=available deployment/$latest_deployment -n $namespace2

# Restart the latest deployment
kubectl rollout restart deployment/$latest_deployment -n $namespace2


echo -e "------postGREST service and pods started------ \n"

# load input data sets in cws-namespace onto management pod

kubectl cp inputs/rnaseq $namespace/management:/input/
kubectl cp inputs/sarek $namespace/management:/input/
kubectl cp inputs/chipseq $namespace/management:/input/
kubectl cp inputs/atacseq $namespace/management:/input/
kubectl cp inputs/mag $namespace/management:/input/
kubectl cp inputs/ampliseq $namespace/management:/input/
kubectl cp inputs/nanoseq $namespace/management:/input/
kubectl cp inputs/viralrecon $namespace/management:/input/
kubectl cp inputs/eager $namespace/management:/input/

kubectl cp setup/nanoseqPatch.diff $namespace/management:/input/

# run commands.sh on management pod
kubectl cp setup/commands.sh $namespace/management:/input/

# apply cws service-account
kubectl apply -f setup/accounts.yaml --namespace $namespace

# label cluster-nodes
kubectl label nodes minikube cwsscheduler=true
kubectl label nodes minikube-m02 minikube-m03 minikube-m04 cwsexperiment=true

# Enable port-forwarding for db & metrics
cd ../ProvenanceEngine
bash port-forwarding.sh

sleep 3

echo -e "--------CWS-Prov-Setup is complete! You can run the workflows now!-------- \n"

# if you face any problems, run this manually in the pod.
# kubectl exec  --namespace $namespace management -- /bin/bash /input/commands.sh
