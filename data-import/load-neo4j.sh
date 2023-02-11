
#!/usr/bin/env bash

ME=load-neo4j.sh

echo "($ME) $(date) Starting (from $IMPORT_DIRECTORY)..."
echo "($ME) $(date) Importing to database $IMPORT_TO"
echo "($ME) $(date) Database root is $NEO4J_dbms_directories_data"

# If the destination database exists
# then do nothing...
if [ ! -d $NEO4J_dbms_directories_data/databases/$IMPORT_TO.db ]
then
    echo "Running as $(id)"
    echo "($ME) $(date) Importing into '$NEO4J_dbms_directories_data/databases/$IMPORT_TO.db'..."

    cd $IMPORT_DIRECTORY
    /var/lib/neo4j/bin/neo4j-admin import \
        --database $IMPORT_TO.db \
        --nodes "xchem-suppliermol-nodes.csv.gz" \
        --nodes "xchem-supplier-nodes.csv.gz" \
        --nodes "xchem-isomol-nodes.csv.gz" \
        --nodes "nodes-header.csv,xchem-augmented-nodes.csv.gz" \
        --nodes "nodes-header.csv,nodes.csv.gz" \
        --relationships "edges-header.csv,edges.csv.gz" \
        --relationships "xchem-suppliermol-supplier-edges.csv.gz" \
        --relationships "xchem-isomol-suppliermol-edges.csv.gz" \
        --relationships "xchem-molecule-suppliermol-edges.csv.gz" \
        --relationships "xchem-isomol-molecule-edges.csv.gz" \
        --skip-bad-relationships \
        --skip-duplicate-nodes
#        --ignore-missing-nodes #THIS DOES NOT WORK IN NEWER VERSIONS, check how to replace it
    echo "($ME) $(date) Imported."
else
    echo "($ME) $(date) Database '$IMPORT_TO' already exists."
fi

echo "($ME) $(date) Finished."
