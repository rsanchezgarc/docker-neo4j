# The InformaticsMatters neo4j container image
A specialised build of neo4j used by a number of InformaticsMatters projects.

To build and push...

    $ docker-compose build
    $ docker-compose push

With a non-default tag...

    $ IMAGE_TAG=test docker-compose build
    $ IMAGE_TAG=test docker-compose push

## Typical execution (Docker)
Assuming you have: -

1.  A data directory (i.e. `~/neo4j-import`) with graph files and a pre-start
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
        -e NEO4J_AUTH=none \
        -e NEO4J_dbms_directories_data=/graph \
        -e NEO4J_dbms_directories_logs=/graph-logs \
        -e IMPORT_DIRECTORY=/data-import \
        -e IMPORT_TO=graph \
        -e EXTENSION_SCRIPT=/data-import/load-neo4j.sh \
        informaticsmatters/neo4j:3.5.2

## Running post-DB cypher commands
The image contains the ability to run a series of cypher commands
after the database has started. It achieves this by running a a provided
`cypher-runner.sh` script located in this image's `/cypher-runner` directory.
This script is executed towards the end of the `docker-entrypoint.sh`
and runs in the background until the provided cypher commands have been
executed.

All you need to do to run your one early cypher commands
is provide them in the file `/cypher-runner/cypher.script` and provide
the neo4j credentials.

An example script may contain the following index and cache-warm-up commands: -

    CREATE INDEX ON :F2(smiles);
    CREATE INDEX ON :VENDOR(cmpd_id);
    CALL apoc.warmup.run(true, true, true);
    
If this script exists as `/cypher-runner/cypher.script`, and the environment
variables `NEO4J_USERNAME` and `NEO4J_PASSWORD` are defined, the script
will be run in the background automatically.

>   The cypher runner waits for a short period of time after neo4j has been
    given an opportunity to start (about 20 seconds) before the first run of
    the script is attempted.

---
