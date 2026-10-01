#!/bin/bash -eux

# Populates target/docker/ (the same build context CI uses, never the source tree directly), then
# builds on the locally built petl image; the Dockerfile's own default is what CI uses.
mvn package

docker build \
  --build-arg PETL_BASE_IMAGE=partnersinhealth/petl:local \
  -t partnersinhealth/zl-etl:local target/docker
