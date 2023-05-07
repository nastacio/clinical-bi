# Overview

under construction

<!-- TOC -->

- [Overview](#overview)
  - [Pull requests](#pull-requests)
  - [Creating local environment](#creating-local-environment)
    - [macOS](#macos)
    - [docker-compose](#docker-compose)
    - [Building](#building)

<!-- /TOC -->
<!-- /TOC -->

## Pull requests

## Creating local environment

### macOS

If you are using a Mac with an M1 chip or higher, you need to install Tensorflow metal plugin for compatability with your architecture:
<https://developer.apple.com/metal/tensorflow-plugin/>

### docker-compose

There is a Docker Compose file in the "docker/build" directory, from where you can standup the components for the estimator:

- `aact`: A Postgresql database engine running the AACT database.
- `tensorflow.ct`: Trains a model for predicting the outcome of a clinical trial.

### Building

```sh
podman-compose build ./build
```
