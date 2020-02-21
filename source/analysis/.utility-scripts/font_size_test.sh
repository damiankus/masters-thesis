#!/usr/bin/env bash

INPUT_FILE="imputed/mice_time_windows.Rda"
OUTPUT_DIR="relationships/test"
EXPLANATORY_VARS=(temperature wind_speed pressure humidity day_of_year hour_of_day precipitation_rate wind_speed wind_dir_deg)
mkdir $OUTPUT_DIR

# IFS - input field separator
function join_by { local IFS="$1"; shift; echo "$*"; }

WIDTH=$1
FONT_MIN=$2
FONT_MAX=$3
FONT_STEP=$4

echo $*

for VAR_COUNT in 2 5 8 10
do
  VARS=`join_by , ${EXPLANATORY_VARS[@]:0:$VAR_COUNT}`
  for (( FONT_SIZE=$FONT_MIN; FONT_SIZE<=$FONT_MAX; FONT_SIZE+=$FONT_STEP ))
  do
    SMALL_FONT_SIZE=10
    
    echo "width: ${WIDTH}, vars count: ${VAR_COUNT}, font size: ${FONT_SIZE}, small font size: ${SMALL_FONT_SIZE}"
    Rscript scatter.R --file $INPUT_FILE --response-variable future_pm2_5 --explanatory-variables $VARS --output-dir $OUTPUT_DIR --width $WIDTH --font-size $FONT_SIZE --small-font-size 10 --output-file "test-width_${WIDTH}-vars_${VAR_COUNT}-font_${FONT_SIZE}-small_font_${SMALL_FONT_SIZE}.png"
  done
done
