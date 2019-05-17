#!/usr/bin/env bash

ME=cypher-runner.sh
SCRIPT=/cypher-runner/cypher.script

echo "($ME) $(date) Starting..."

if [ -z "$NEO4J_USERNAME" ]
then
    echo "($ME) $(date) No NEO4J_USERNAME. Can't run without this."
    exit 0
fi
if [ -z "$NEO4J_PASSWORD" ]
then
    echo "($ME) $(date) No NEO4J_PASSWORD. Can't run without this."
    exit 0
fi

if [ -f $SCRIPT ]
then

    echo "($ME) $(date) Processing cypher.script. Pre-neo4j pause..."
    sleep 20

    echo "($ME) $(date) Trying cypher.script..."
    until cat $SCRIPT | /var/lib/neo4j/bin/cypher-shell
    do
        echo "($ME) $(date) No joy, waiting..."
        sleep 4
    done
    echo "($ME) $(date) Script executed."

else
    echo "($ME) $(date) No cypher.script."
fi

echo "($ME) $(date) Finished."
