# Defaults to the published base image, so CI can build this. build-runtime-docker-image.sh
# overrides it with partnersinhealth/petl:local for local builds.
ARG PETL_BASE_IMAGE=partnersinhealth/petl:latest
FROM ${PETL_BASE_IMAGE}

COPY datasources /home/petl/configurations/datasources
COPY jobs /home/petl/configurations/jobs
COPY application-docker.yml /home/petl/bin/application.yml
