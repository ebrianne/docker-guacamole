# Alpine-based Guacamole-server and client

![Build/Push (master)](https://github.com/ebrianne/docker-guacamole/workflows/Build/Push%20(master)/badge.svg?branch=master)
[![Docker Pulls](https://img.shields.io/docker/pulls/ebrianne/docker-guacamole.svg)](https://hub.docker.com/r/ebrianne/docker-guacamole/)
[![GitHub issues](https://img.shields.io/github/issues/ebrianne/docker-guacamole?style=for-the-badge)](https://github.com/ebrianne/docker-guacamole/issues)

## Acknowledgments

This image has been inspired from [oznu/guacamole](https://github.com/oznu/docker-guacamole).

## Quick Start

This container contains guacamole-server and client. The guacamole server only listens locally.

```
$ docker run -v /your/storage/path/to/config/:/config \
             -p 8080:8080 \
             ebrianne/docker-guacamole
```

## Docker Compose
```
version: '3'
services:
    guacamole:
      volumes:
        - /your/storage/path/to/config/:/config
      environment:
        - TZ=Europe/Berlin
      ports:
        - '8080:8080'
      image: ebrianne/docker-guacamole
