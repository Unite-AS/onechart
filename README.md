# One chart to rule them all

A generic Helm chart for your application deployments.

Because no-one can remember the Kubernetes yaml syntax.


## Getting started

OneChart is a generic Helm Chart for web applications. The idea is that most Kubernetes manifest look alike, only very few parts actually change.

Add the Onechart Helm repository:

```bash
helm repo add onechart https://unite-as.github.io/onechart/
```

Set your image name and version, the boilerplate is generated.

```bash
helm template my-release Unite-AS/onechart \
  --set image.repository=nginx \
  --set image.tag=1.19.3
```

The example below deploys your application image, sets environment variables and configures the Kubernetes Ingress domain name:

```bash
helm repo add onechart https://unite-as.github.io/onechart/
helm template my-release Unite-AS/onechart -f values.yaml

# values.yaml
image:
  repository: my-app
  tag: fd803fc
vars:
  VAR_1: "value 1"
  VAR_2: "value 2"
ingress:
  annotations:
    kubernetes.io/ingress.class: nginx
  host: my-app.mycompany.com
```

### Alternative: using an OCI repository
You can also template and install onechart from an OCI repository as follows:

Check the generated Kubernetes yaml:

```bash
helm template my-release oci://ghcr.io/unite-as/onechart/onechart --version 0.62.0 \
  --set image.repository=nginx \
  --set image.tag=1.19.3
```

Deploy with Helm:

```bash
helm install my-release oci://ghcr.io/unite-as/onechart/onechart --version 0.62.0 \
  --set image.repository=nginx \
  --set image.tag=1.19.3
```

## Contribution Guidelines

Below are some guidelines and best practices for contributing to this repository:

### Issues

If you are running a fork of OneChart and would like to upstream a feature, please open a pull request for it.

### New Features

If you are planning to add a new feature to OneChart, please open an issue for it first. Helm charts are prone to having too many features, and OneChart want to keep the supported use-cases in-check. Proposed features have to be generally applicable, targeting newcomers to the Kubernetes ecosystem.

### Pull Request Process

* Fork the repository.
* Create a new branch and make your changes.
* Open a pull request with detailed commit message and reference issue number if applicable.
* A maintainer will review your pull request, and help you throughout the process.

## Development

Development of OneChart does not differ from developing a regular Helm chart.

The source for OneChart is under `charts/onechart` where you can locate the `Chart.yaml`, `values.yaml` and the templates.

We write unit tests for our helm charts. Pull requests are only accepted with proper test coverage.

The tests are located under `charts/onechart/test` and use the https://github.com/helm-unittest/helm-unittest Helm plugin to run the tests.

For installation, refer to the CI workflow at `.github/workflows/build.yaml`.

## Build and Release Process

### Building and Testing Locally

1. **Lint the charts**:
   ```bash
   make lint
   ```

2. **Run tests**:
   ```bash
   make test
   ```

3. **Package the charts**:
   ```bash
   make package
   ```

or

**Run all steps at once**:
   ```bash
   make all
   ```

The `make all` command will lint, test, and package the Helm charts. The packaged chart archives (`.tgz` files) are placed in the `docs/` directory.

### Updating the Helm Repository Index

After packaging new chart versions, you need to update the Helm repository index:

```bash
helm repo index docs --url https://unite-as.github.io/onechart/
```

This command generates or updates the `index.yaml` file in the `docs/` directory, which is the Helm repository manifest that lists all available charts and their versions.

### Release Process

1. Update the chart version in the respective `Chart.yaml` file
2. Run `make all` to test and package the updated chart
3. Update the Helm repository index as described above
4. Commit and push your changes
5. Create a git tag for the new version
6. Push the tag to trigger the GitHub Actions workflow

The chart archives in the `docs/` directory, along with the updated `index.yaml`, are served via GitHub Pages at https://unite-as.github.io/onechart/.

GitHub Actions is configured to automate these steps on git tag events, making the release process smoother.
