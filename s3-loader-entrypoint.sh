#!/bin/bash

# NOTE: The image that uses this entrypoint is also employed by Squonk
#       as part fo the ChemCentral loader process, where RAW vendor data
#       is copied into a /data volume.
#
#       Importantly: Setting CYPHER_ROOT to '' disables the neo4j-specific
#                    post-processing done by this script.

#       When used for Squonk's ChemCentral Database...
#
#       AWS_ACCESS_KEY_ID       is set
#       AWS_SECRET_ACCESS_KEY   is set
#       AWS_BUCKET              is set ('im-fragnet')
#       AWS_BUCKET_PATH         is a path to RAW vendor files
#                               (like 'raw/vendor/molport/2021-02')
#       CYPHER_ROOT             is empty ('')
#       GRAPH_WIPE              is 'no'
#       SYNC_PATH               is a vendor-specific path
#                               (like 'molport-2021-02')

# We need some key environment variables
# before we do anything sensible...
#
# AWS_*         Are AWS credentials for accessing the S3 bucket
# CYPHER_ROOT   The path to the cypher script directory (typically /data)
# GRAPH_WIPE    If 'yes' then all data is erased, forcing
#               a resync with S3 and a reload of the Graph data
# POST_SLEEP_S  A value (seconds) to sleep at the end of the script.
#               this allows the user to inspect the environment prior
#               to the execution moving to the graph container.
# SYNC_PATH     Is the directory to synchronise S3 content with
#               Typically the data-loader directory
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
if [ "$GRAPH_WIPE" = "yes" ]; then
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

# If CYPHER_ROOT has a meaningful value...
# then it's where cypher scripts (and '.executed') files are kept.
if [ -n "$CYPHER_ROOT" ]; then
  CYPHER_PATH="$CYPHER_ROOT/cypher-script"
  echo "Making cypher path directory ($CYPHER_PATH)..."
  mkdir -p "$CYPHER_PATH"
else
  echo "CYPHER_ROOT is blank, skipping cypher path directory prep."
fi

# We only pull down data if it looks like the sync-path has no loader script.
# Pulling down data again is time-consuming and we insect the
# files in the loader script later in this script...
LOAD_SCRIPT=load-neo4j.sh
if [ ! -f "/data/${SYNC_PATH}/${LOAD_SCRIPT}" ]; then

  # Remove any 'always.executed' file.
  # This will be re-created by the graph container
  # when the 'always script' finishes.
  ALWAYS_EXECUTED_FILE="$CYPHER_PATH/always.executed"
  if [ -f "$ALWAYS_EXECUTED_FILE" ]; then
    echo "Removing always executed file ($ALWAYS_EXECUTED_FILE)"
    rm -f "$ALWAYS_EXECUTED_FILE" || true
  fi

  echo "Downloading import data..."

  echo "Making SYNC_PATH directory (/data/${SYNC_PATH})..."
  mkdir -p "/data/${SYNC_PATH}"

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
  echo "Copying objects to /data/${SYNC_PATH}..."
  for PATH_OBJECT in $PATH_OBJECTS; do
    aws s3 cp \
      "s3://${AWS_BUCKET}/${AWS_BUCKET_PATH}/${PATH_OBJECT}" \
      "/data/${SYNC_PATH}/${PATH_OBJECT}"
  done

  echo "Displaying copied objects (in /data/${SYNC_PATH})..."
  ls -l "/data/${SYNC_PATH}"

  echo "Download complete."

else

  echo "Skipping download - ${LOAD_SCRIPT} exists"

fi

# Where will the database appear?
# Only interested in this if there's a CYPHER_ROOT
# (i.e. we're dealing with neo4j)
if [ -n "$CYPHER_ROOT" ]; then
  echo "Making ultimate data directory (/data/data)..."
  mkdir -p "/data/data"
fi

# If we're not dealing with neo4j then we leave now - all we need
# to do is download data from S3 - everything else in this file
# relates to dealing with a loader that's used for neo4j data.
#
# We're not dealing with neo4j if CYPHER_ROOT is empty.
if [ -z "$CYPHER_ROOT" ]; then
  echo "CYPHER_ROOT is empty - data not for neo4j. Leaving."
  exit 0
fi

# Are all the neo4j files present?
#
# To protect against 'broken' deployment or failed downloads
# We check that the loader script is present, and extract the list of nodes
# and relationships it refers to to 'load-files.txt'.
# We then iterate 'load-files.txt' and if any file is not
# present we stop.
#
# Is the loader script present?
echo "Sanity check (${LOAD_SCRIPT})..."
pushd "/data/${SYNC_PATH}"
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
echo "${LOAD_SCRIPT} FILES=${FILES}"
echo "${LOAD_SCRIPT} MISSING_FILES=${MISSING_FILES}"
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
