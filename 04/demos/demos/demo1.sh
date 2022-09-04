#Deploy cluster with AZ Support
#Create a resource group for this demo
az group create --name aks-az --location centralus


#1 - Create an AZ Aware AKS Cluster with a node in each zone.
az aks create \
    --resource-group aks-az \
    --name aks-az \
    --generate-ssh-keys \
    --node-count 3 \
    --zones 1 2 3


#Get the kubeconfig to log into the cluster
az aks get-credentials --resource-group aks-az --name aks-az


#Examine the labels associated with the nodes, will tell you the topology of the cluster
kubectl get nodes -L topology.kubernetes.io/region,topology.kubernetes.io/zone


#Create a workload
kubectl create deployment hello-world \
    --image=gcr.io/google-samples/hello-app:1.0 \
    --replicas=3


#By default the scheduler will spread the workload across all nodes, and thus all AZs
kubectl get pods -o wide


#If we scale the cluster it will keep the node count as even as possible accross the AZs.
az aks scale \
    --resource-group aks-az  \
    --name aks-az  \
    --node-count 6


#Check out the topology of the cluster after the scaling operation...we will get 1 additional node per AZ
kubectl get nodes -L topology.kubernetes.io/region,topology.kubernetes.io/zone




#2 - Create another resource group in a paired azure region
az group create --name aks-az2 --location eastus2


#Create an AZ aware cluster
az aks create \
    --resource-group aks-az2 \
    --name aks-az2 \
    --generate-ssh-keys \
    --node-count 3 \
    --zones 1 2 3


#Get log in credentials to that cluster
az aks get-credentials --resource-group aks-az2 --name aks-az2


#Start a workload in eastus2
kubectl create deployment hello-world-loadbalancer-eastus2 \
    --image=gcr.io/google-samples/hello-app:1.0 --replicas=3


#Expose it using a LoadBalancer
kubectl expose deployment hello-world-loadbalancer-eastus2 \
    --port=80 --target-port=8080 --type LoadBalancer


#Wait for the EXTERNAL-IP to populate...
kubectl get service --watch 


#Get the load balancer's IP address
LOADBALANCERIP2=$(kubectl get service hello-world-loadbalancer-eastus2 -o jsonpath='{ .status.loadBalancer.ingress[].ip }')
echo $LOADBALANCERIP2


#Change to our centralus cluster
kubectl config use-context aks-az


#Create a workload in centralus
kubectl create deployment hello-world-loadbalancer-centralus \
    --image=gcr.io/google-samples/hello-app:1.0 --replicas=3


#Expose it using a LoadBalancer
kubectl expose deployment hello-world-loadbalancer-centralus \
    --port=80 --target-port=8080 --type LoadBalancer


#Wait for the EXTERNAL-IP to populate...
kubectl get service --watch 


#Get the load balancer's IP address
LOADBALANCERIP1=$(kubectl get service hello-world-loadbalancer-centralus -o jsonpath='{ .status.loadBalancer.ingress[].ip }')


#Make sure we have both populated
echo $LOADBALANCERIP1
echo $LOADBALANCERIP2


#Test access to each service
curl http://$LOADBALANCERIP1
curl http://$LOADBALANCERIP2


#Create a Traffic Manager profile, this DNSNAME will become part of the URL we'll point to
DNSNAME="psdemo$RANDOM"
az network traffic-manager profile create \
  --name aks-atm \
  --resource-group aks-az2 \
  --routing-method Priority \
  --unique-dns-name $DNSNAME


#Create an endpoint pointing to the public IP of load balancer in centralus. This can also be an AppGW too. 
az network traffic-manager endpoint create \
  --resource-group aks-az2  \
  --profile-name aks-atm \
  --name centralus \
  --type externalEndpoints \
  --priority 1 \
  --target $LOADBALANCERIP1


#Create an endpoint pointing to the public IP of load balancer in eastus2. This can also be an AppGW too. 
az network traffic-manager endpoint create \
  --resource-group aks-az2  \
  --profile-name aks-atm \
  --name eastus2 \
  --type externalEndpoints \
  --priority 2 \
  --target $LOADBALANCERIP2


#Test accessing out application, which region are we hitting? 
curl http://$DNSNAME.trafficmanager.net


#Delete the deployment supporting the active ATM profile...just one...not both
kubectl config use-context aks-az
kubectl delete deployment hello-world-loadbalancer-centralus 


#Delete the deployment supporting the active ATM profile...just one...not both
kubectl config use-context aks-az2
kubectl delete deployment hello-world-loadbalancer-eastus2 

#Wait about 90 seconds...
sleep 90


#Default failover policy is 30 sec check interval and 3 failed checks...so we'll have to wait about 90 seconds
curl http://$DNSNAME.trafficmanager.net



#Clean up after this demo
#az group delete --name aks-az
#az group delete --name aks-az2
