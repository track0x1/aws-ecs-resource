# AWS ECS Resource

Perform rolling deployments with AWS ECS.

## Source Configuration

* `cluster_name`: *Required.* ECS cluster name.

* `image_name`: *Required.* Base docker image name to use in your ECS services. Should *not* include a tag.

* `region`: *Required.* AWS region for deployments.

### Example

Configuration with deploy to canary, and production.

``` yaml
resource_types:
  - name: aws-resource
    type: docker-image
    source:
      repository: track0x1/aws-ecs-resource

resources:
  - name: app-code
    type: git
    # ... git resource config here
  - name: aws
    type: aws-resource
    source:
      cluster_name: app-code-cluster
      image_name: registry.hub.docker.com/my-app-code
      region: us-east-1

jobs:
  - name: canary
    plan:
      - get: app-code
      - put: aws
        params:
          service_name: app-code-canary
          tag: app-code/.git/ref
  - name: prod
    plan:
      - get: aws
        passed: [canary]
      - put: aws
        params:
          cache: aws
          service_name: app-code-prod
```

## Behavior

### `check`: No-op.

### `in`: Retrieve task definition

Retrieves the provided task definition and saves it to `./history`. This file is consumed in subsequent `put` operations.

### `out`: Deploy ECS Task Definition to a service

Creates a copy of the current task definition and updates the image field with the provided docker image and tag. Then updates the provided service with the new task definition. If provided a cache and task definition has already been created, it will use the cache and quickly update the provided service with the task definition (instead of creating a new task definition).

#### Parameters

* `cache`: *Optional.* Path to AWS resource that performed a `get` (essentially just the name of the resource). You will only need to provide cache when you wish to use the same task definition in subsequent Concourse jobs.

* `service_name`: *Required.* Name of the ECS service to update.

* `tag`: *Optional.* Path to a file that contains the tag of your docker image. We typically use a `resource-name/.git/ref` (from _git-resource_).
