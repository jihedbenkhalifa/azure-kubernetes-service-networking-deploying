#Deploy a cluster with an AppGW Ingress Controller for application access
az group create --name AKS-AppGW --location centralus


##Create a cluster with the AppGW Ingress addon
az aks create \
    --resource-group AKS-AppGW  \
    --name AKSClusterAppGW \
    --network-plugin azure \
    --enable-managed-identity \
    --enable-addon ingress-appgw \
    --appgw-name aks-appgw \
    --appgw-subnet-cidr "10.225.0.0/16" \
    --generate-ssh-keys


#Get the kubeconfig to log into the cluster
az aks get-credentials --resource-group "AKS-AppGW" --name AKSClusterAppGW


#Create a Deployment, ClusterIP Service, and Ingress to access our application via AppGW
kubectl apply -f ingress-path.yaml


#Our current application is running on three pods
kubectl get pods -o wide


#Wait for the IP address to populate for the ingress...this can take a minute or two to update.
kubectl get ingress --watch


#Access the application via the exposed ingress on the public IP
INGRESSIP=$(kubectl get ingress -o jsonpath='{ .items[].status.loadBalancer.ingress[].ip }')
echo $INGRESSIP


#Access our application via the ingress
curl http://$INGRESSIP


#Our ingress controller is a pod running in the cluster...
#monitoring for ingress resources and updating the configuration of the AppGW
kubectl describe pods -n kube-system -l app=ingress-appgw | more


#Open the Azure Portal, search for AKSClusterAppGW and go to the Managed Cluster Resource Group
# and find the deployed AppGW
#0. Observe the stats on the landing page
#1. On Backend Pools you'll find a pool pointing the to nodes in the cluster
#2. Traffic is sent from the AppGW straight to the Pod IPs on Azure CNI since they're all on the same subnet


#Clean up from this demo
#az group delete --name AKS-AppGW
