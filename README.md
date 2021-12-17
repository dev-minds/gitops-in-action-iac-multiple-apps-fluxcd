Ncloud project
---

- Architecture design
- Ability to present solutions
- Engineering skills
- Documentation
- Security


This is a setup that ochestrates deployment of ghost blog to a kubernetes cluster, in our case EKS 
This setup integrate multiple devops tools to achieve a deployment. Below are the following steps we have implemented to 

### Create networking layers (VPC|Subnets etc)
Navigate to [networking-infra](https://github.com/timonyia/ncloud-gblog-proj/tree/master/infra/networking)
>Resources include 
* Basic VPC module 
* subnet configuration 
* NATG toggle 
* ECR setup
* terraform version: v0.12.31

Networking infra cicd with github actions workfow can be found [here](https://github.com/timonyia/ncloud-gblog-proj/blob/master/.github/workflows/infra-networking-cd.yaml)
>GHA actions include
```ruby
- name: Checkout
uses: actions/checkout@1.0.0

- name: Configure AWS credentials
uses: aws-actions/configure-aws-credentials@v1

- name: Setup Terraform
uses: hashicorp/setup-terraform@v1

```
### Create platform(EKS) for deployment infra 
Navigate to [platform-infra](https://github.com/timonyia/ncloud-gblog-proj/tree/master/infra/platform)
>Resources include
* Third party EKS module
* Dynamic networking interpolation 
* EKS v1.20 
* terraform version: v0.12.31

>Authenticate to cluster after creation 
```ruby
aws sts get-caller-identity
aws eks --region eu-west-1 update-kubeconfig --name ncloud-gblog-proj-cluster
kubectl config get-contexts
```

platform infra cicd with github actions workfow can be found [here](https://github.com/timonyia/ncloud-gblog-proj/blob/master/.github/workflows/infra-platform-cd.yaml)
>GHA actions include
```ruby
- name: Checkout
uses: actions/checkout@1.0.0

- name: Configure AWS credentials
uses: aws-actions/configure-aws-credentials@v1

- name: Setup Terraform
uses: hashicorp/setup-terraform@v1
```
### Build and push application to ECR (GitHub Action)
Navigate to [ecr-image-build](https://github.com/timonyia/ncloud-gblog-proj/blob/master/.github/workflows/app-docker-builder.yaml)
>Components include 
* ECR repo 
* Image build workflow with GHA
>Authenticate to ECR locally 
```ruby
aws ecr get-login-password --region eu-west-1 | docker login --username AWS --password-stdin 303577xxxxx.dkr.ecr.eu-west-1.amazonaws.com
```
### Export github token to your machine/flux instance
```ruby
export GITHUB_TOKEN=YOURGITHUBTOKEN
```

### Bootstrap platform(EKS) with fluxCD
```ruby
flux bootstrap github --owner timonyia --repository flux-controller --branch master --path apps --personal true --components-extra=image-reflector-controller,image-automation-controller --token-auth
```

### Clone the created flux management repo locally 
```ruby
git clone https://github.com/timonyia/flux-controller  # Make sure you are able to push to this repo with the right creds 
```

```ruby
$ kubectl get pods -n flux-system 
NAME                                           READY   STATUS    RESTARTS   AGE
helm-controller-869cbdd784-4gtgq               1/1     Running   0          65m
image-automation-controller-7655f57596-49lwq   1/1     Running   0          65m
image-reflector-controller-7b89476565-vr52v    1/1     Running   0          65m
kustomize-controller-9b95c7748-tswtf           1/1     Running   0          65m
notification-controller-f9b7dc79d-snj79        1/1     Running   0          65m
source-controller-7975f5b479-d8f45             1/1     Running   0          65m
```

### Setup fluxcd sources and kustomizations 
Navigate to flux management repo `flux-controller` 
```ruby 
cd flux-controller/
```

Run below commands from the flux-controller repo 
```ruby
flux create source git ncloud-gblog-proj-source --url https://github.com/timonyia/ncloud-gblog-proj.git --branch master --interval 30s --export | tee apps/ncloud-gblog-proj-source.yaml
flux create kustomization ncloud-gblog-proj-source --source ncloud-gblog-proj-source --path "./deployment/flux-kustomizer" --prune true --validation client --interval 10m --export | tee -a apps/ncloud-gblog-proj-source.yaml 
```

Above command essentially creates|generates and merges a new `manifest file` for your sources and kusmtomization components. 
Push this new file to the flux management repo 
```ruby
git add --all ; git -am "sources and kustomization components added" ; git push origin master 
```

Next watch the synchronization happen based on the changed components with below commands 

```ruby
flux get source git ; flux get kustomization 
NAME                            READY   MESSAGE                                                                 REVISION                                        SUSPENDED 
flux-system                     True    Fetched revision: master/2946a5144624abc62d6a286c5babb823666763ba       master/2946a5144624abc62d6a286c5babb823666763ba False    
ncloud-gblog-proj-source        True    Fetched revision: master/04df242257cd11859b1171c35ee9b3fe29dc0663       master/04df242257cd11859b1171c35ee9b3fe29dc0663 False    
NAME                            READY   MESSAGE                                                                 REVISION                                        SUSPENDED 
flux-system                     True    Applied revision: master/2946a5144624abc62d6a286c5babb823666763ba       master/2946a5144624abc62d6a286c5babb823666763ba False    
ncloud-gblog-proj-source        True    Applied revision: master/04df242257cd11859b1171c35ee9b3fe29dc0663       master/04df242257cd11859b1171c35ee9b3fe29dc0663 False 
```

### Deploy app components via repo with flux(gitOps)
>test|staging|prod environment 
```ruby
ncloud-gblog-proj/deployment/flux-kustomizer/test-env
test-env[master] $ ll 
total 32
-rw-r--r--  1 felixm  181693646  133 15 Nov 20:07 kustomization.yaml
-rw-r--r--  1 felixm  181693646   75 15 Nov 20:09 test-env-ns.yaml
-rw-------  1 felixm  181693646  225 15 Nov 20:12 service.yaml
-rw-------  1 felixm  181693646  516 15 Nov 20:14 deployments.yaml
```

### Deploy monitoring components via repo with flux(gitOps)
Navigate to [monitoring-components](https://github.com/timonyia/ncloud-gblog-proj/tree/master/deployment/flux-kustomizer/cluster-monitoring)
>Components include 
* Grafana 
* Prometheus 

### App routing and ingress configuration 
1. Install ingress controller on cluster via cli
```ruby
kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/controller-v1.0.0/deploy/static/provider/cloud/deploy.yaml

$ k get ns 
NAME                 STATUS   AGE
default              Active   158m
flux-system          Active   138m
ingress-nginx        Active   44s   # Ingress Controller sits on the ingress-nginx NS
kube-node-lease      Active   158m
kube-public          Active   158m
kube-system          Active   158m
test-env-ghostblog   Active   56m
$ kcd ingress-nginx

$ k get po 
NAME                                        READY   STATUS      RESTARTS   AGE
ingress-nginx-admission-create-kb5qq        0/1     Completed   0          71s
ingress-nginx-admission-patch-nr96c         0/1     Completed   1          71s
ingress-nginx-controller-65c4f84996-lsf2r   1/1     Running     0          71s
```
2. Create ingress object per environment please see sample file in the test-env as below  

```ruby
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: test-env-ingress
  namespace: test-env-ghostblog
  annotations:
    kubernetes.io/ingress.class: nginx
spec:
  rules:
  - host: "test-env.aws.mycloudlearning.uk"
    http:
      paths:
      - pathType: Prefix
        path: "/"
        backend:
          service:
            name: test-env-ghostblog
            port:
              number: 80
```

3. View all available ingress currently deployed, please note - we have one single LB serving multiple applications on different namespaces 
```ruby
k get ing -A 
NAMESPACE               NAME                  CLASS    HOSTS                                ADDRESS                                                                   PORTS   AGE
monitoring              mon-env-ingress       <none>   monitoring.aws.mycloudlearning.uk    aa5c0806e27224c50aeac2e5b02ee1e5-1755909412.eu-west-1.elb.amazonaws.com   80      4m9s
staging-env-ghostblog   staging-env-ingress   <none>   staging-env.aws.mycloudlearning.uk   aa5c0806e27224c50aeac2e5b02ee1e5-1755909412.eu-west-1.elb.amazonaws.com   80      20m
test-env-ghostblog      test-env-ingress      <none>   test-env.aws.mycloudlearning.uk      aa5c0806e27224c50aeac2e5b02ee1e5-1755909412.eu-west-1.elb.amazonaws.com   80      27m
```

### Configure cluster dashboard 
Manual setup of rancher with [user-guide](https://rancher.com/docs/rke/latest/en/config-options/)


### Cleanup resources and components 
1. Run the platform destroyer job [here](https://github.com/timonyia/ncloud-gblog-proj/actions/workflows/infra-platform-eks-destroy.yaml)
2. Delete any ophan LoadBalancer on your AWS 
