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
        
---

## Neo4j extensions

Download apoc library from https://github.com/neo4j-contrib/neo4j-apoc-procedures/releases
Download graph algororithms library from https://github.com/neo4j-contrib/neo4j-graph-algorithms/releases

