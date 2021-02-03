# The InformaticsMatters neo4j container image

[![CodeFactor](https://www.codefactor.io/repository/github/informaticsmatters/docker-neo4j/badge)](https://www.codefactor.io/repository/github/informaticsmatters/docker-neo4j)

A specialised build of neo4j used by a number of InformaticsMatters projects.

The repo contains image definitions for our Graph database, and a loader
that populates the graph from an S3 bucket and path.

To build and push...

    $ docker-compose build
    $ docker-compose push

## Typical execution (Docker)
Assuming you have: -

1.  A data directory (i.e. `~/neo4j-import`) with graph files, and a pre-start
    batch loader script in it called `load-neo4j.sh`
1.  A directory for logs (i.e. `~/neo4j-container-logs`)
1.  A directory to mount for the generated Neo4j database
    (i.e. `~/neo4j-container-graph`)

...then you should be able to start the database
with the following docker command: -

    $ docker run --rm \
        -v $HOME/neo4j-import:/data-import \
        -v $HOME/neo4j-container-logs:/graph-logs \
        -v $HOME/neo4j-container-graph:/graph \
        -p 7474:7474 \
        -p 7687:7687 \
        -e GRAPH_PASSWORD=blob1234 \
        -e NEO4J_dbms_directories_data=/graph \
        -e NEO4J_dbms_directories_logs=/graph-logs \
        -e IMPORT_DIRECTORY=/data-import \
        -e IMPORT_TO=graph \
        -e EXTENSION_SCRIPT=/data-import/load-neo4j.sh \
        informaticsmatters/neo4j:3.5.25

## Running post-DB cypher commands
The image contains the ability to run a series of cypher commands
after the database has started. It achieves this by running the
`cypher-runner.sh` script located in this image's `/cypher-runner` directory.
This script is executed towards the end of the `docker-entrypoint.sh`
and runs in the background until the provided cypher commands have been
executed.

All you need to do to run your own cypher commands
is to provide them in the either a `/cypher-runner/cypher-script.once`
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

## docker-entrypoint tweaks
**CAUTION**: We replace the supplied neo4h `docker-entrypoint.sh` script with
our own variant. It adds some extra logic, all identified and briefly documents
by comments that begin `IM-BEGIN` and end with `IM-END`.

## Plugins
We've added the following plugins to the image: -

1.  **Neo4j Graph Data Science Library** from the [community] section of the
    download-centre
    (formally the graph-algorithms-algo library we used in our 3.5 image)
2.  **Neo4j Apoc Procedure**, a collection of useful Neo4j Procedures
    from the [apoc] distribution on Maven.

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
[community]: https://neo4j.com/download-center/#community
[warming up]: https://neo4j-contrib.github.io/neo4j-apoc-procedures/3.5/operational/warmup/
