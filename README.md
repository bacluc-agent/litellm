# Wrapper chart for [litellm](https://github.com/BerriAI/litellm)

This wrapper chart is intended to be used in conjunction with [AppFlow](https://control.vshn.net/appflow/apps)

## Initial Setup

### Setup with VSHNPostgreSQL

Helm tries to install the dependencies before it installs manifests from the wrapper chart.
This fails due to postgres not being available.
This means the [VSHNPostgresql](/templates/vshnpostgresql.yaml) needs to be rendered locally and applied to the cluster before trying to roll out a deployment for the first time.

## Configuration

### Environment Variables

Apart from the usual AppFlow variables, additionally environment variable can be set via environment variables in CI/CD settings.
You need to have the APPFLOW_ prefix to inject them.

#### API-Keys to llm providers

In addition to setting them in the environment pipeline settings they need to be referenced in the model_list, like:

```yaml
      - model_name: "opencode/deepseek-v4"
        litellm_params:
          model: "openai/deepseek-v4"
          api_base: "os.environ/OPENCODE_API_BASE"
          api_key: "os.environ/OPENCODE_2_API_KEY"
```

### Namespace

The namespace is created via AppFlow.
Once the namespace is created we need to additionally set the label for the [solution-base-monitoring](https://github.com/appuio/component-solution-base-monitoring) and the cluster-monitoring label `openshift.io/cluster-monitoring: "true"`.
