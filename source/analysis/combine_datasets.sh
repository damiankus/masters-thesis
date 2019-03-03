#!/usr/bin/env bash

export RAW_DATA_DIR='raw_datasets';
export PREPROCESSED_DIR='preprocessed';
export RAW_FILE="${PREPROCESSED_DIR}/observations_no_outliers.Rda";
export SERIES_FILE="${PREPROCESSED_DIR}/observations.Rda";
export TIME_WINDOWS_FILE="data/time_windows.Rda";

export COMMON_SCATTER_PARAMS="--response-variable future_pm2_5 --file ${TIME_WINDOWS_FILE} --output-dir relationships";
export TIME_VARIABLES="measurement_time,is_holiday,is_heating_season,year,season,month,day_of_week,day_of_year,hour_of_day,period_of_day";
export TIME_PARAMS="$COMMON_SCATTER_PARAMS --explanatory-variables $TIME_VARIABLES";
export SCALED_TIME_VARIABLES="is_holiday,is_heating_season,season_scaled,month_scaled,day_of_week_scaled,day_of_year_scaled,hour_of_day_scaled"
export SCALED_TIME_PARAMS="$COMMON_SCATTER_PARAMS --explanatory-variables $SCALED_TIME_VARIABLES";
export METEO_VARIABLES="pm2_5,pm10,wind_speed,wind_dir_deg,precip_rate,solradiation,temperature,humidity,pressure";
export METEO_PARAMS="$COMMON_SCATTER_PARAMS --explanatory-variables $METEO_VARIABLES";

rm -rf $RAW_DATA_DIR
rm -rf $PREPROCESSED_DIR
mkdir $RAW_DATA_DIR
mkdir $PREPROCESSED_DIR

psql -d air_quality -a -f combine_observations.sql
sudo mv /tmp/*observations*.csv $RAW_DATA_DIR/

Rscript preprocess_raw_db_dumps.R --source-dir $RAW_DATA_DIR --target-dir $PREPROCESSED_DIR

Rscripts count_missing.R --file $SERIES_FILE

# Draw yearly trends
Rscript draw_trend.R --file $SERIES_FILE --output-dir trend

# Draw boxplots
Rscript draw_boxplot.R --file $SERIES_FILE --output-dir boxplot

# Create time windows containing aggregated values
Rscript save_time_windows.R --file $SERIES_FILE --output-file $TIME_WINDOWS_FILE --past-lag 23 --future-lag 24;

# Draw scatter plots to visualise relationships between variables
Rscript draw_scatterplot.R $COMMON_SCATTER_PARAMS $METEO_PARAMS --use-aggregated;
Rscript draw_scatterplot.R $COMMON_SCATTER_PARAMS $TIME_PARAMS --output-file time_vars_relationships.png;
Rscript draw_scatterplot.R $COMMON_SCATTER_PARAMS $SCALED_TIME_PARAMS --output-file time_scaled_vars_relationships.png;

# Draw autocorrelation plots (ACF and PACF)
Rscript draw_acf.R --file $TIME_WINDOWS_FILE --output-dir autocorrelation --variable pm2_5;