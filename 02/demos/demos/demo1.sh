#Deploying a cluster to a new virtual network (kubenet)
az login
az account set --subscription "Demonstration Account"


#Create a resource group for the serivces we're going to create
az group create --name "AKS-Cloud" --location centralus


#Let's create our AKS cluster with default settings
#this will create our virtual network and subnet and will use kubenet.
az aks create \
    --resource-group "AKS-Cloud" \
    --generate-ssh-keys \
    --name AKSCluster1


#Get the kubeconfig to log into the cluster
az aks get-credentials --resource-group "AKS-Cloud" --name AKSCluster1


#Open the Azure Portal, search for AKSCluster1, click on the AKS Service, review the network configuration. 


#Open the Azure Portal, search for AKSCluster1, click on the Managed Cluster Resource Group, click on the VNet
#Examine the VNet address and subnet address


#Nodes are assigned IP addresses from the virtual network that was created by the cluster deployment automatically. 
kubectl get nodes -o wide


#Look at Addresses.InternalIP and PodCIDR, you will see the network range for each node that Pod IPs are allocated from. 
#PodCIDRs will have addressing information for IPV4 and IPV6 if in use.
kubectl describe nodes | more


#Create a workload
kubectl create deployment hello-world \
    --image=gcr.io/google-samples/hello-app:1.0 \
    --replicas=3


#Each Pod is allocated an IP address from the Node's PodCIDR Range.  
kubectl get pods -o wide


#Show parameters for specifying the IP address ranges, Service, PodCIDR, and the network to attach to with vnet-subnet-id
az aks create --help


#We're going to keep this cluster around for some later demos so let's not delete it yet, but if you need to...here you go
#az group delete --name "AKS-Cloud" 
