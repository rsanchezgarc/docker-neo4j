# The InformaticsMatters neo4j container image

[![CodeFactor](https://www.codefactor.io/repository/github/informaticsmatters/docker-neo4j/badge)](https://www.codefactor.io/repository/github/informaticsmatters/docker-neo4j)

A specialised build of neo4j used by a number of InformaticsMatters projects.

The repo contains image definitions for our Graph database and a loader
that populates the graph from an AWS S3 path.

To build and push...

    $ docker-compose build #Create image from repository
    $ docker-compose push #Do not push if you are not sure

## Typical execution (Docker)

By default, it will create a tiny fragment network included in the repo, if you want to use one, create a directory
with the required content (like the one in ./data-import) and add to the docker run the volume (`-v ~/your/local/data/neo4j-import:/data-import \`)

...then you should be able to start the database
with the following docker command: -

    $ docker run --rm \
    -v ~/tmp/neo4j-container-logs:/graph-logs \
    -v ~/tmp/neo4j-container-graph:/graph \
    -p 7474:7474 \
    -p 7687:7687 \
    -e NEO4J_AUTH=neo4j/blob1234 \
    -e NEO4J_dbms_directories_data=/graph \
    -e NEO4J_dbms_directories_logs=/graph-logs \
    -e IMPORT_DIRECTORY=/data-import \
    -e IMPORT_TO=graph \
    -e EXTENSION_SCRIPT=/data-import/load-neo4j.sh \
    -e GRAPH_PASSWORD=blob1234 \
    -e NEO4J_USERNAME=neo4j \
    -e NEO4J_dbms_security_procedures_unrestricted=algo\.\* \
    CONTAINER_ID

## Running post-DB cypher commands
The image contains the ability to run a series of cypher commands
after the database has started. It achieves this by running a provided
`cypher-runner.sh` script located in this image's `/cypher-runner` directory.
This script is executed towards the end of the `docker-entrypoint.sh`
and runs in the background until the provided cypher commands have been
executed.

All you need to do to run your own early cypher commands
is to provide them in either a `/cypher-runner/cypher-script.once`
or `/cypher-runner/cypher-script.always` file and provide
the neo4j credentials.

An example `.once` script may contain the following index commands: -

    CREATE INDEX ON :F2(smiles);
    CREATE INDEX ON :VENDOR(cmpd_id);
    
An example `.always` script may contain the following cache-warm-up commands: -

    CALL apoc.warmup.run(true, true, true);

>   This command helps improve query performance by quickly [warming up] the
    page-cache by touching pages in parallel optionally loading
    property-records, dynamic-properties and indexes

If the environment variables `NEO4J_USERNAME` and `NEO4J_PASSWORD` are defined,
the scripts will be run in the background automatically.

>   The cypher runner waits for a short period of time after neo4j has been
    given an opportunity to start (about 60 seconds) before the first run of
    the script is attempted. This can be configured in the image (refer
    to the cypher-runner script for the environment variables it inspects).

## docker-entrypoint tweaks
**CAUTION**: We replace the supplied neo4h `docker-entrypoint.sh` script with
our own variant. It adds some extra logic, all identified and briefly documents
by comments that begin `IM-BEGIN` and end with `IM-END`.

## Plugins
We've added the following plugins to the image: -

1.  **Neo4j Graph Data Science Library** [gds] from the [community] section of
    the download-centre
    (formally the graph-algorithms-algo library we used in our 3.5 image)
2.  **Neo4j Apoc Procedure**, a collection of useful Neo4j Procedures
    from the [apoc] distribution on Maven.

>   The changes to `dbms.security.procedures.unrestricted` take place in the
    **Dockerfile** where it's written to `/var/lib/neo4j/conf/neo4j.conf`.

## The enterprise container image
Although a build is made available for the Enterprise container
you are not permitted to use it unless you are in possession of a
valid licence agreement.
    
## The ansible role and playbook
The Ansible role and corresponding playbook has been written to simplify
deployment of the neo4j image along with an associated AWS S3-based graph.

The role deploys an S3-based loader prior to spinning-up the neo4j instance. 

---

[apoc]: https://mvnrepository.com/artifact/org.neo4j.procedure/apoc
[gds]: https://neo4j.com/docs/graph-data-science/current/installation/
[community]: https://neo4j.com/download-center/#community
[warming up]: https://neo4j-contrib.github.io/neo4j-apoc-procedures/3.5/operational/warmup/
