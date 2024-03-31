#!/bin/bash
namespace="cws"

# setup of cws related stuff
kubectl create namespace $namespace
#kubectl apply -f setup/pv.yaml --namespace $namespace
kubectl apply -f setup/pvc.yaml --namespace $namespace
kubectl apply -f setup/daemonset.yaml -n $namespace
kubectl -n $namespace wait --for=condition=ready pod -l name=sysbench --timeout=600s
echo "Waiting for management pod to be started..."
sleep 30
kubectl apply -f setup/management.yaml --namespace $namespace
kubectl wait --for=condition=ready pod management --namespace $namespace

#calling setup script for Provenance Engine
echo "Setting up Provenance Engine"
bash prov_setup.sh

# load input data sets in cws-namespace onto management pod

echo "Upload data"
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
kubectl label nodes cpu01 cwsscheduler=true
kubectl label nodes cpu02 cpu03 cpu08 cpu09 cpu10 cwsexperiment=true


# if you face any problems, run this manually in the pod.
kubectl exec  --namespace $namespace management -- /bin/bash /input/commands.sh
