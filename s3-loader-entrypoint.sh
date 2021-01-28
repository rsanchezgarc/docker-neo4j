#!/bin/sh

# We need some key environment variables
# before we do anything sensible...
#
# AWS_*         Are AWS credentials for accessing the S3 bucket
# SYNC_PATH     Is the directory to synchronise S3 content with
#               Typically the data-loader directory
# GRAPH_WIPE    If 'yes' then all data is erased, forcing
#               a resync with S3 and a reload of the Graph data
# CYPHER_ROOT   The path to the cypher script directory (typically /data)
# POST_SLEEP_S  A value (seconds) to sleep at the end of the script.
#               this allows the user to inspect the environment prior
#               to the execution moving to the graph container.
#
# After downloading the source files the loader expects:
#
# - A 'load-neo4j.sh' script in /data/${SYNC_PATH}
# - The loader script must refer to at least one file
# - All files referred to must exist
#
# If these conditions aren't met the loader halts (does not exit).

: "${AWS_ACCESS_KEY_ID?Need to set AWS_ACCESS_KEY_ID}"
: "${AWS_SECRET_ACCESS_KEY?Need to set AWS_SECRET_ACCESS_KEY}"
: "${AWS_BUCKET?Need to set AWS_BUCKET}"
: "${AWS_BUCKET_PATH?Need to set AWS_BUCKET_PATH}"
: "${CYPHER_ROOT?Need to set CYPHER_ROOT}"
: "${GRAPH_WIPE?Need to set GRAPH_WIPE}"
: "${SYNC_PATH?Need to set SYNC_PATH}"

# If GRAPH_WIPE is 'yes' then the /data directory is
# erased prior to running the S3 sync.
if [ "$GRAPH_WIPE" = "yes" ]
then
  echo "Wiping graph data (GRAPH_WIPE=$GRAPH_WIPE)..."
  rm -rf /data/*
else
  echo "Preserving existing graph data (GRAPH_WIPE=$GRAPH_WIPE)"
fi

# Remove the graph debug log if NEO4J_dbms_directories_logs is defined
if [ -n "$NEO4J_dbms_directories_logs" ]; then
  DEBUG_FILE="$NEO4J_dbms_directories_logs"/debug.log
  echo "Removing debug log ($DEBUG_FILE)"
  rm -f "$DEBUG_FILE" || true
fi

# Where are the scripts (and '.executed') files kept?
CYPHER_PATH="$CYPHER_ROOT/cypher-script"
echo "Making cypher path directory ($CYPHER_PATH)..."
mkdir -p "$CYPHER_PATH"

# We only pull down data (causing a potential re-build of the database
# and indexes) if it looks like there's no graph database.
# There's likely to be a database if the file '/data/data/dbms/auth' exists -
# it's created by neo4j. Pulling data when there is a database is pointless.
if [ ! -f "/data/data/dbms/auth" ]; then

  # Remove any 'always.executed' file.
  # This will be re-created by the graph container
  # when the 'always script' finishes.
  ALWAYS_EXECUTED_FILE="$CYPHER_PATH/always.executed"
  if [ -n "$ALWAYS_EXECUTED_FILE" ]; then
    echo "Removing always executed file ($ALWAYS_EXECUTED_FILE)"
    rm -f "$ALWAYS_EXECUTED_FILE" || true
  fi

  echo "Downloading import data..."

  # List the bucket's objects (files).
  # Output is typically: -
  #
  #   2019-07-29 18:06:05          0 combine-done
  #   2019-07-29 18:05:57          0 done
  #   2019-07-29 18:03:41         38 edges-header.csv
  #   2019-07-30 19:48:00 22699163411 edges.csv.gz
  #
  # And we want...
  #
  #   combine-done
  #   done
  #   edges-header.csv
  #   edges.csv.gz
  echo "Listing S3 path (${AWS_BUCKET}/${AWS_BUCKET_PATH})..."
  LS_CMD="aws s3 ls s3://${AWS_BUCKET}/${AWS_BUCKET_PATH}/"
  PATH_OBJECTS=$($LS_CMD | tr -s ' ' | cut -d ' ' -f 4)

  # Now copy each object to the local SYNC_PATH
  echo "Copying objects..."
  for PATH_OBJECT in $PATH_OBJECTS; do
    aws s3 cp \
      "s3://${AWS_BUCKET}/${AWS_BUCKET_PATH}/${PATH_OBJECT}" \
      "/data/${SYNC_PATH}/${PATH_OBJECT}"
  done

  # Where will the database appear?
  echo "Making ultimate data directory (/data/data)..."
  mkdir -p "/data/data"

  echo "Download complete."

else

  echo "Skipping download - database appears to exist"

fi

# Are all the files present?
#
# To protect against 'broken' deployment or failed downloads
# We check that the loader script is present, and extract the list of nodes
# and relationships it refers to to 'load-files.txt'.
# We then iterate 'load-files.txt' and if any file is not
# present we stop.
#
# Is the loader script present?
pushd "/data/${SYNC_PATH}"
LOAD_SCRIPT=load-neo4j.sh
if [ ! -f "${LOAD_SCRIPT}" ]; then
  echo ":ERROR: '${LOAD_SCRIPT}' is missing"
  echo ":HALT:"
  sleep infinity
fi
# Dissect the script - pulling out the node and relationship files...
grep '\-\-nodes' "${LOAD_SCRIPT}" | cut -d\" -f2 | cut -d\, -f1 > load-files.txt
grep '\-\-nodes' "${LOAD_SCRIPT}" | cut -d\" -f2 | cut -d\, -f2 >> load-files.txt
grep '\-\-relationships' "${LOAD_SCRIPT}" | cut -d\" -f2 | cut -d\, -f1 >> load-files.txt
grep '\-\-relationships' "${LOAD_SCRIPT}" | cut -d\" -f2 | cut -d\, -f2 >> load-files.txt
# Now check the files, counting each one that cannot be found.
# We must have at least one file in the list.
FILES=0
MISSING_FILES=0
while read line; do
  FILES=$(($FILES + 1))
  if [ ! -f "${line}" ]; then
    echo "File '${line}' is missing!"
    MISSING_FILES=$(($MISSING_FILES + 1))
  fi
done <<< $(cat load-files.txt)
echo "FILES=${FILES}"
echo "MISSING_FILES=${MISSING_FILES}"
# If any files are missing then stop...
if [ "${FILES}" == "0" ]; then
  echo ":ERROR: There were no files"
  echo ":HALT:"
  sleep infinity
fi
if [ "${MISSING_FILES}" != "0" ]; then
  echo "ERROR: Some files were missing"
  echo ":HALT:"
  sleep infinity
fi
popd

# If there's 'once' or 'always' content then place it
# in the expected location for the corresponding cypher scripts.
if [ "$CYPHER_ONCE_CONTENT" ]; then
  cypher_file=cypher-script.once
  echo "Writing $CYPHER_PATH/$cypher_file..."
  echo "$CYPHER_ONCE_CONTENT" > "$CYPHER_PATH/$cypher_file"
fi
if [ "$CYPHER_ALWAYS_CONTENT" ]; then
  cypher_file=cypher-script.always
  echo "Writing $CYPHER_PATH/$cypher_file..."
  echo "$CYPHER_ALWAYS_CONTENT" > "$CYPHER_PATH/$cypher_file"
fi

# Has a POST_SLEEP_S been defined?
if [ "$POST_SLEEP_S" ]; then
  echo "POST_SLEEP_S=$POST_SLEEP_S sleeping..."
  sleep "$POST_SLEEP_S"
  echo "Slept."
else
  echo "POST_SLEEP_S is not defined - leaving now..."
fi
