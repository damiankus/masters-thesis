#!/usr/bin/env bash

RAW_DATA_DIR='raw_datasets'
PREPROCESSED_DIR='preprocessed'

rm -rf $RAW_DATA_DIR
rm -rf $PREPROCESSED_DIR
mkdir $RAW_DATA_DIR
mkdir $PREPROCESSED_DIR

psql -d air_quality -a -f combine_observations.sql
sudo mv /tmp/*observations*.csv $RAW_DATA_DIR/

Rscript preprocess_raw_db_dumps.R --source-dir $RAW_DATA_DIR --target-dir $PREPROCESSED_DIR
