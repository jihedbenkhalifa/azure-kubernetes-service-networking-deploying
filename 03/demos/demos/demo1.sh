#Create LoadBalancer services for application access
#We're going to focus on imperative commands here. If you want to dig into declarative configurations check out
#my course: Configuring and Managing Kubernetes Networking, Services and Ingress  


#Let's set to the kubectl context back to our local custer that we created in module 2 demo 1
kubectl config use-context AKSCluster1


#Let's create a deployment
kubectl create deployment hello-world-loadbalancer \
    --image=gcr.io/google-samples/hello-app:1.0 \
    --replicas=3


#When creating a service, you can define a type, if you don't define a type, the default is ClusterIP
kubectl expose deployment hello-world-loadbalancer \
    --port=80 \
    --target-port=8080 \
    --type LoadBalancer


#Can take a minute for the load balancer to provision and get an public IP, you'll see EXTERNAL-IP as <pending>
#We get a cluster IP listening on Port 80, External IP listening on Port 80, and a NodePort Service listening on Port 31000-32767
kubectl get service


#Let's test access to our application via the load balancer over the internet on the public IP address.
LOADBALANCERIP=$(kubectl get service hello-world-loadbalancer -o jsonpath='{ .status.loadBalancer.ingress[].ip }')
curl http://$LOADBALANCERIP


#Log into the Azure Portal, locate your Managed Cluster Resource Group and find the following
#0. Search for 'AKSCluster1' 
#1. Find the Load Balancer named kubernetes
#2. "Frontend IP Configuration" = The public IP of the Service 
#3. "Backend Pools" = The actual Node's IP addresses on the Node Subnet
#4. "Health Probes" = The node port services probes
#5. "Load balancing rules" = Defines the route of the traffic from the load balancer to the node and nodeport


#Clean up the resources from this demo
kubectl delete deployment hello-world-loadbalancer
kubectl delete service hello-world-loadbalancer


#We're done with this cluster now, so you can delete it if needed.
#az group delete --name "AKS-Cloud" 



###More example with other service types...ClusterIP and NodePort
kubectl create deployment hello-world-clusterip \
    --image=gcr.io/google-samples/hello-app:1.0 \
    --replicas=3


#Expose the service
kubectl expose deployment hello-world-clusterip \
    --port=80 \
    --target-port=8080 \
    --type ClusterIP


#Since ClusterIP is only available inside the cluster...let's get a terminal on a node in our cluster 
#and then access the ClusterIP Service from that node
NODE=$(kubectl get nodes -o jsonpath='{ .items[0].metadata.name }')
kubectl debug node/$NODE -it --image=ubuntu
apt-get update && apt-get install curl -y

#We can use service discovery to find our ClusterIP Service IP
env | sort | grep HELLO_WORLD


#Access our application
curl http://$HELLO_WORLD_CLUSTERIP_SERVICE_HOST


#exit from the node
exit


#Clean up from this demo
kubectl delete deployment hello-world-clusterip
kubectl delete service hello-world-clusterip


#Let's do a nodeport example
kubectl create deployment hello-world-nodeport \
    --image=gcr.io/google-samples/hello-app:1.0 \
    --replicas=3


#Expose the service
kubectl expose deployment hello-world-nodeport \
    --port=80 \
    --target-port=8080 \
    --type NodePort


#Take note of of the actual NodePort Service Port. 
#In the example output below for kubectl get service, my NodePort Service Port is 321331.
#Yours will likely be different since its dynamically allocated.
#NAME                   TYPE        CLUSTER-IP     EXTERNAL-IP   PORT(S)        AGE
#hello-world-nodeport   NodePort    10.0.254.242   <none>        80:32331/TCP   3m39s  
kubectl get service


#NodePort is available external to the cluster but we don't have direct remote access onto our Azure Virtual Network that our nodes are on
#So we can open a shell to one of the nodes and access the NodePort service from there. 
NODE=$(kubectl get nodes -o jsonpath='{ .items[0].metadata.name }')
kubectl debug node/$NODE -it --image=ubuntu
apt-get update && apt-get install curl -y


#Access our application, you can send traffic to any node in the cluster on the NodePort Service Port
#Try sending a request to each node in the cluster

#Your request needs to be in the format of 
curl http://PASTE_ANY_NODENAME_HERE:NODEPORTPORT


#This an example URL string to access the nodeport service
#curl http://aks-nodepool1-36349573-vmss000000:32331


#exit from the node
exit


#Clean up from this demo
kubectl delete deployment hello-world-nodeport
kubectl delete service hello-world-nodeport