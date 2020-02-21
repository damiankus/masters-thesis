#!/usr/bin/env bash

INPUT_FILE="imputed/mice_time_windows.Rda"
OUTPUT_DIR="relationships/test/small"
BASE_FONT_RESULTS_FILE="relationships/font_sizes.csv"
EXPLANATORY_VARS=(temperature wind_speed pressure humidity day_of_year hour_of_day precipitation_rate wind_speed wind_dir_deg)
mkdir $OUTPUT_DIR

# IFS - input field separator
function join_by { local IFS="$1"; shift; echo "$*"; }

SMALL_FONT_MIN=$1
SMALL_FONT_MAX=$2
SMALL_FONT_STEP=$3

tail --lines=+2 $BASE_FONT_RESULTS_FILE | while IFS=, read -r WIDTH VAR_COUNT FONT_SIZE
do
  VARS=`join_by , ${EXPLANATORY_VARS[@]:0:$VAR_COUNT}`
  for (( SMALL_FONT_SIZE=SMALL_FONT_MIN; SMALL_FONT_SIZE<=SMALL_FONT_MAX; SMALL_FONT_SIZE+=$SMALL_FONT_STEP ))
  do
    echo "width: ${WIDTH}, vars count: ${VAR_COUNT}, font size: ${FONT_SIZE}, small font size: ${SMALL_FONT_SIZE}"
    Rscript scatter.R --file $INPUT_FILE --response-variable future_pm2_5 --explanatory-variables $VARS --output-dir $OUTPUT_DIR --width $WIDTH --font-size $FONT_SIZE --small-font-size $SMALL_FONT_SIZE --output-file "small-test-width_${WIDTH}-vars_${VAR_COUNT}-font_${FONT_SIZE}-small_font_${SMALL_FONT_SIZE}.png"
  done
  
# Skip the header
done
