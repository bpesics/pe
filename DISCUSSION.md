## How would a new deployment look like for these services? What kind of tools would you use?

### Additional configuration
* The deployment of the *pe(antaeus)* repo should probably not depend on the *pe-payment* repo as it is currently. The *pe-payment* repo should have independent deployment(`kustomize/`) files.
* set resource requests & limits for containers
* add Ingress resources
* use a production ready WSGI server for Flask (pe-payment)
* decide on rollout strategy (Recreate vs RollingUpdate vs Canary)

### Kustomize

In my opionion _Kustomize_ is preferable over _Helm_ for deployments like this (it's documentation leaves a lot to be desired though).

Additional *overlays* for other environments would probably be necessary and those would also benefit from advanced Kustomize features like:
- [nameSuffix](https://kubectl.docs.kubernetes.io/references/kustomize/kustomization/namesuffix/)
- various [patching techniques](https://kubectl.docs.kubernetes.io/references/kustomize/kustomization/patches/)
- [configMapGenerator](https://kubectl.docs.kubernetes.io/references/kustomize/kustomization/configmapgenerator/)
- [components](https://github.com/kubernetes-sigs/kustomize/blob/master/examples/components.md) (DRY)
- some [Transformer Configuration](https://github.com/kubernetes-sigs/kustomize/tree/master/examples/transformerconfigs) ;)

As an alternative when it comes to generating and managing large Kubernetes manifest structures I'd look at [Tanka](https://tanka.dev/tutorial/jsonnet) (Jsonnet).

### Helm

In the case a product needs to be packaged for (third party) users (and needs more complex templating) _Helm_ could be a good choice.

*It's worth considering how enourmously complicated packages like that of `GitLab` first moved from one giant package to multiple smaller packages then moved on to build an [_operator_](https://gitlab.com/gitlab-org/cloud-native/gitlab-operator#gitlab-operator)...)*

### CI/CD

Currently I am using an "artisan" `deploy.sh` to:
* run `kustomize`
* apply `envsubst` for some templating
* run db migrations (pre, post, none at all)
* etc.

I would look for alternatives:
 * [GitLab Auto DevOps](https://docs.gitlab.com/ee/topics/autodevops/). I haven't used it and I'm a bit sceptical. (Btw. the Kubernetes integration in GitLab is still quite useful for connecting to clusters.)
 * On *GitHub* using Actions would be an obvious choice, provides great tooling nowadays. Actions are also a more flexible approach than GitLab's built-in one.
 * I would consider https://fluxcd.io/ as well for a pull based workflow.
 * perhaps [Dagger](https://docs.dagger.io/1007/kubernetes/)

### Secrets
* avoid using long-term access keys wherever possible (instead use *IAM roles for service accounts* and similar)
* GitLab Environment (variables) management (not so great with many variables IMO)
* GitHub Environment secrets (not so great with many variables IMO)
* something like Mozilla KOPS ([KSOPS](https://github.com/viaduct-ai/kustomize-sops))

### Monitoring
* Prometheus `ServiceMonitor` objects if the application services provided metrics
  * *JVM* with a Prometheus *JMX* exporter
  * *Flask* also has a Prometheus exporter
* configure logging in both services for production (format, verbosity etc.)
  * use [fluentbit.io/parser](https://docs.fluentbit.io/manual/pipeline/filters/kubernetes#kubernetes-annotations) annotations in the case of using fluent-bit

### Autoscaling
* HPA
* [KEDA](https://keda.sh/docs/2.7/scalers/)

### Local

Somethimes it's good to have tools available locally for iteration and be able to make a deployment to a testing environemnt without a commit. As in the exercise projects I tend to use `asdf` for tools installation and version pinning (did not have much succes with _linux_ `brew`).

I would argue against using a docker image for tools locally because I find it cumbersome to do things like `alias aws='docker run --rm -it -v ~/.aws:/root/.aws -v $(pwd):/aws amazon/aws-cli'` and if the specific tool has a file output then it gets even more complicated. Having said that for CI an image with the same version of tools is required. Might be useful to use the same `.tool-versions` file to build that image.

Another tool I'd recommend is [direnv](https://direnv.net/). It makes it possible navigate in a directory structure and automate things like:
  * selecting a project specific `.aws_config` file (`AWS_CONFIG_FILE`)
  * selecting `kubeconfig` files (`KUBECONFIG`)
  * set environment variables like that of the environment name (DRY and naming conventions).

This is probably more relevant when it comes to managing an infrastructure (provisioning) and less so for application deployments.

for example:
```
env/
├── production
│   ├── .envrc
│   ├── kubernetes
│   │   ├── .kube_config
│   └── terraform
├── testing
    ├── .envrc
    ├── kubernetes
    │   ├── .kube_config
    └── terraform
```

## If a developers needs to push updates to just one of the services, how can we grant that permission without allowing the same developer to deploy any other services running in K8s?

* A possible solution is to delegate access management to an external tool as CI/CD (push like ordinary pipelilnes or pull like Flux or GitLab agent). Then the question becomes who has permissions to trigger a deployment to which environment:
  * [merge request approval rules](https://docs.gitlab.com/ee/user/project/merge_requests/approvals/)
  * [other means of protecting environments](https://docs.gitlab.com/ee/ci/environments/protected_environments/#protecting-environments)
  * separate deployment project/repo (with a different set of members)
  * even in the case mentionedd above it's worth restricting the deployment tool to something else then the default cluster-admin role (principle of least privilege + separation of duty)
* Kubernetes Authorization with RBAC
  * for instance restrict access to a single namespace by binding the default `ClusterRole/admin`  with `RoleBinding` in the specific namespace to a `ServiceAccount`(deployment agent) or `Group/User` subject

## How do we prevent other services running in the cluster to talk to your service. Only Antaeus should be able to do it.

* *network policy(ingress)* with `namespaceSelector` or `podSelector` (requires a CNI network plugin which implements this feature)
* manually implement client certificate authentication (mTLS) within the serving pod (with the aid of an Nginx reverse proxy for instance)
* [mTLS with service mesh](https://istio.io/latest/docs/tasks/security/authentication/mtls-migration/)