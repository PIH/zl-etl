Zanmi Lasante(ZL) - ETL Jobs to support reporting and analytics from OpenMRS at APZU
============================================================================

This repository hold the ETL files for ZL.

# Installation

For implementers, see [Puppet](https://github.com/PIH/mirebalais-puppet/tree/master/mirebalais-modules/petl)

### Install Java
The recommended Java version is **OpenJDK 8 JDK**

### Source MySQL databases
You must have access to MySQL databases for the instances that you plan to use as sources.
The recommendation is that these databases are replicas of production DBs, not the actual production instances, as a 
precaution to ensure no production data is inadvertently affected by the ETL process.

### Target SQL Server databases
* You must have access to a SQL Server target instance into which to ETL from MySQL
* You can use the Docker instance [described here](https://github.com/PIH/petl/tree/master/docs/examples/sqlserver-docker).

### Install PETL application and jobs

1. Create a directory to serve as your execution environment directory
2. Install the jobs and datasources into this directory
   1. For developers, create a symbolic link to the datasources and jobs folders of this project
   2. For implementers, download the zip artifact from maven and extract it into this directory
3. Install an application.yml file into this directory
   1. For developers, copy or create a symolic link to example-application.yml, and modify settings to match your database configuration
   2. For implementers, install the application.yml file, and ensure all of the database settings are setup correctly
   3. For more details on configuration options for application.yml, see the [PETL](https://github.com/PIH/petl) project
4. Install the PETL executable jar file
   1. For developers, you can clone and build the PETL application locally and create a symbolic link to target/petl-*.jar
   2. For developers or implementers, you can download the latest PETL jar from Bamboo

The directory structure should look like this:

```bash
configurations/datasources#
.
├── openmrs-cange.yml
├── openmrs-hinche.yml
├── openmrs-hiv.yml
├── openmrs-humci.yml
├── openmrs-lacolline.yml
├── openmrs-mirebalais.yml
├── openmrs-saint_marc_hsn.yml
├── openmrs-thomonde.yml
└── warehouse.yml

configurations/jobs#
- create-partitions.yml  
- create-source-views-and-functions.yml  
- import-to-table-partition.yml  
- refresh-base-tables.yml  
- refresh-hiv-data.yml  
- refresh-humci-data.yml  
- refresh-openmrs-data.yml  
- sql folder
```

# Execution

To execute the ETL pipeline

```shell
service petl start
```
# Docker image

`partnersinhealth/zl-etl` layers this project's `datasources/`, `jobs/` and `application-docker.yml`
(as its `application.yml`) on the [PETL](https://github.com/PIH/petl) base image,
`partnersinhealth/petl`. CI builds and pushes it (`Dockerfile`, build context `target/docker/`,
populated by `mvn package`) on every push and on every release, tagged `latest` and the version.
It builds on `partnersinhealth/petl:latest` (the `Dockerfile`'s `PETL_BASE_IMAGE` default). To build it locally: `./build-runtime-docker-image.sh`, which
layers on a locally built `partnersinhealth/petl:local`.

It runs as [openmrs-contrib-distro-tools](https://github.com/PIH/openmrs-contrib-distro-tools)'
`petl` service (see its `docs/services.md`), e.g. for the zl-ci CI server:

    PETL_IMAGE_NAME=partnersinhealth/zl-etl
    PETL_FULL_REFRESH_JOBS="create-partitions.yml refresh-ci-warehouse.yml"
    PETL_SQLSERVER_DATABASE=openmrs_zl_ci

`application-docker.yml` maps the `zlci` OpenMRS datasource and the `warehouse` SQL Server
datasource onto distro-tools' `PETL_MYSQL_*` and `PETL_SQLSERVER_*` variables. The other sites'
datasources aren't set; set one by its Spring environment-variable name where it's needed (e.g.
`DATASOURCES_OPENMRS_<SITE>_HOST`).
