# Exercise

## Changes
- a GitHub Actions based workflow has been added to build and publish the *Antaeus* container image
  - the resulting image is available at `ghcr.io/bpesics/pe:latest`
  - a `LABEL` has been added to the `Dockerfile` to assign images to the forked repo
- a `docker-compose-payment.yml` has been added to support testing with the new payment service
  - usage: `docker-compose -f docker-compose-payment.yml up`
- added a `Makefile`, `kustomize/` folder and an [asdf](https://asdf-vm.com/) `.tool-versions` file for deployment

## Solution

### Payment service

See https://github.com/bpesics/pe-payment

### Deployment overview

As a good practice the project attempts to pin tool versions:
* this is only `kubectl` and `jq` at this point
* if you already have these installed it's not a hard prerequisite to install [asdf](https://asdf-vm.com/)
* if you need to install these tools install asdf and use the provided `make` target: `make install-asdf-tools`

*Kustomize* (should be built into recent kubectl versions) is used for the deployment with a fairly conventional structure:
```
kustomize
├── base
│   ├── antaeus
│   └── payment
└── overlays
    └── testing  # let's imagine the exercise is deployed into the "testing" environemnt
```

### Deployment

From the project root:

* observe what would be deployed: `kubectl kustomize kustomize/overlays/testing/ | less`
* dry-run with client side strategy: `kubectl apply -k kustomize/overlays/testing/  --dry-run=client`
* apply configuration: `kubectl apply -k kustomize/overlays/testing/`
  * should see something along the lines of this:
    ```
    namespace/app-antaeus created
    namespace/app-payment created
    configmap/antaeus-config-env-468bcg9db8 created
    service/antaeus created
    service/payment created
    deployment.apps/antaeus created
    deployment.apps/payment created
    ```

### Testing the deployment

Observe deployment and logs:
```
# antaeus startup takes time
kubectl -n app-antaeus rollout status -w deployment antaeus
kubectl -n app-antaeus logs deployment.apps/antaeus -f

kubectl -n app-payment logs deployment.apps/payment -f
```

For in-cluster testing the command `make shell-multitool` is provided. Once in the shell:
```
{
  curl -i -w "\n" http://payment.app-payment:9000/health
  curl -i -w "\n" http://antaeus.app-antaeus:8000/rest/health
}

# count number of PAID invoices
curl -s http://antaeus.app-antaeus:8000/rest/v1/invoices | jq '[.[] | select(.status == "PAID") ] | length'

# attempt to pay invoices
curl -X POST -i -w "\n" http://antaeus.app-antaeus:8000/rest/v1/invoices/pay

# count number of PAID invoices again
curl -s http://antaeus.app-antaeus:8000/rest/v1/invoices | jq '[.[] | select(.status == "PAID") ] | length'
```

### External access

The cluster where I did my exercise has no `cloud-controller-manager`. Therefore no `Ingress` is provided but instead a more generic `NodePort` type `Service` is configured.

If `kube-proxy` is not restricted to specific IP addresses (and firewall rules also allow) the service should be available on the nodes' external interfaces as well, so something like the following should work:
```
NODE_IP="<external ip address>"
curl http://$NODE_IP:30008/rest/health
```

## Discussion

see [DISCUSSION.md](DISCUSSION.md)

## Notes for testing Antaeus locally
```
curl http://localhost:8000/rest/health
curl -s http://localhost:8000/rest/v1/invoices | jq
curl -X POST http://localhost:8000/rest/v1/invoices/pay
```

---

# Original README

## The challenge

Pleo runs most of its infrastructure in Kubernetes. It's a bunch of microservices talking to each other and performing various tasks like verifying card transactions, moving money around, paying invoices ...

We would like to see that you both:
- Know how to create a small microservice
- Know how to wire it together with other services running in Kubernetes

We're providing you with a small service (Antaeus) written in Kotlin that's used to charge a monthly subscription to our customers. The trick is, this service needs to call an external payment provider to make a charge and this is where you come in.

You're expected to create a small payment microservice that Antaeus can call to pay the invoices. You can use the language of your choice. Your service should randomly succeed/fail to pay the invoice.

On top of that, we would like to see Kubernetes scripts for deploying both Antaeus and your service into the cluster. This is how we will test that the solution works.

## Instructions

Start by forking this repository. :)

1. Build and test Antaeus to make sure you know how the API works. We're providing a `docker-compose.yml` file that should help you run the app locally.
2. Create your own service that Antaeus will use to pay the invoices. Use the `PAYMENT_PROVIDER_ENDPOINT` env variable to point Antaeus to your service.
3. Your service will be called if you invoke `/rest/v1/invoices/pay` call on Antaeus. You can probably figure out which call returns the current status invoices by looking at the code ;)
4. Kubernetes: Provide deployment scripts for both Antaeus and your service. Don't forget about Service resources so we can call Antaeus from outside the cluster and check the results.
    - Bonus points if your scripts use liveness/readiness probes.
5. **Discussion bonus points:** Use the README file to discuss how this setup could be improved for production environments. We're especially interested in:
    1. How would a new deployment look like for these services? What kind of tools would you use?
    2. If a developers needs to push updates to just one of the services, how can we grant that permission without allowing the same developer to deploy any other services running in K8s?
    3. How do we prevent other services running in the cluster to talk to your service. Only Antaeus should be able to do it.

## How to run

If you want to run Antaeus locally, we've prepared a docker compose file that should help you do it. Just run:
```
docker-compose up
```
and the app should build and start running (after a few minutes when gradle does its job)

## How we'll test the solution

1. We will use your scripts to deploy both services to our Kubernetes cluster.
2. Run the pay endpoint on Antaeus to try and pay the invoices using your service.
3. Fetch all the invoices from Antaeus and confirm that roughly 50% (remember, your app should randomly fail on some of the invoices) of them will have status "PAID".
