#!/usr/bin/env bash

export SQL_DUMP_DIR='sql_dumps';
export PREPROCESSED_DIR='preprocessed';

export RAW_FILE="${PREPROCESSED_DIR}/observations_raw.Rda";
export FILTERED_FILE="${PREPROCESSED_DIR}/observations_filtered.Rda";
export IQR_FILE="${PREPROCESSED_DIR}/observations_iqr.Rda";

export METEO_RAW_FILE="${PREPROCESSED_DIR}/meteo_observations_raw.Rda";
export METEO_FILTERED_FILE="${PREPROCESSED_DIR}/meteo_observations_filtered.Rda";
export METEO_IQR_FILE="${PREPROCESSED_DIR}/meteo_observations_iqr.Rda";

export SERIES_FILE="${PREPROCESSED_DIR}/observations.Rda";
export TIME_WINDOWS_FILE="data/time_windows.Rda";
export VARS_WITH_OUTLIERS="temperature,pressure"
export TIME_VARIABLES="measurement_time,is_holiday,is_heating_season,year,season,month,day_of_week,day_of_year,hour_of_day,period_of_day";
export SCALED_TIME_VARIABLES="is_holiday,is_heating_season,season,month_cosine,day_of_week_cosine,day_of_year_scaled,hour_of_day_scaled"
export METEO_VARIABLES="pm2_5,pm10,wind_speed,wind_dir_deg,precip_rate,solradiation,temperature,humidity,pressure";

export COMMON_SCATTER_PARAMS="--file $TIME_WINDOWS_FILE --output-dir relationships --response-variable future_pm2_5";
export TIME_PARAMS="$COMMON_SCATTER_PARAMS --explanatory-variables $TIME_VARIABLES";
export TIME_PARAMS_COSINE="--explanatory-variables $SCALED_TIME_VARIABLES";
export METEO_PARAMS="--explanatory-variables $METEO_VARIABLES";

rm -rf $SQL_DUMP_DIR
rm -rf $PREPROCESSED_DIR
mkdir $SQL_DUMP_DIR
mkdir $PREPROCESSED_DIR

psql -d air_quality -a -f combine_observations.sql
sudo mv /tmp/*observations*.csv $SQL_DUMP_DIR/

# Preprocess SQL dumps to make them usable with R
Rscript preprocess_raw_db_dumps.R --source-dir $SQL_DUMP_DIR --target-dir $PREPROCESSED_DIR;

# Count missing observations for each variable and station
Rscript count_missing.R --file $SERIES_FILE

# Draw response distribution
Rscript draw_distribution.R --file $RAW_FILE --output-dir distribution/raw --variables pm2_5 --group-by month;
Rscript draw_distribution.R --file $METEO_RAW_FILE --output-dir distribution/raw --variables $VARS_WITH_OUTLIERS --group-by month;
Rscript draw_distribution.R --file $FILTERED_FILE --output-dir distribution/filtered --variables pm2_5 --group-by month;
Rscript draw_distribution.R --file $METEO_FILTERED_FILE --output-dir distribution/filtered --variables $VARS_WITH_OUTLIERS --group-by month;
Rscript draw_distribution.R --file $METEO_IQR_FILE --output-dir distribution/iqr --variables $VARS_WITH_OUTLIERS --group-by month;
Rscript draw_distribution.R --file $SERIES_FILE --output-dir distribution --variables pm2_5;

# Draw yearly trends
Rscript draw_trend.R --file $SERIES_FILE --output-dir trend --variables pm2_5 --type yearly,daily;

# Draw boxplots
Rscript draw_boxplot.R --file $SERIES_FILE --output-dir boxplots --variables pm2_5 --split-by season --group-by hour_of_day,day_of_week;
Rscript draw_boxplot.R --file $SERIES_FILE --output-dir boxplots --variables pm2_5 --group-by season,month,day_of_week,hour_of_day,;

# Impute missing values
Rscript save_imputed_series.R --file $SERIES_FILE --output-file $MICE_SERIES_FILE --method mice --test-year 2017;

# Create time windows containing aggregated values
Rscript save_time_windows.R --file $SERIES_FILE --output-file $TIME_WINDOWS_FILE --past-lag 23 --future-lag 24;

# Calculate basic statistics
Rscript save_basic_statistics.R --file $TIME_WINDOWS_FILE --output-dir statistics --variable pm2_5;

# Draw scatter plots to visualise relationships between variables
Rscript draw_scatterplot.R $COMMON_SCATTER_PARAMS $METEO_PARAMS --use-aggregated;
Rscript draw_scatterplot.R $COMMON_SCATTER_PARAMS $TIME_PARAMS --output-file time_vars_relationships.png;
Rscript draw_scatterplot.R $COMMON_SCATTER_PARAMS $TIME_PARAMS_COSINE --output-file time_scaled_vars_relationships.png;
Rscript draw_scatterplot.R $COMMON_SCATTER_PARAMS --output-file base_variables_relationships.png;
Rscript draw_scatterplot.R $COMMON_SCATTER_PARAMS --output-file filtered_base_variables_relationships.png --filter-aggregated;

# Draw autocorrelation plots (ACF and PACF)
Rscript draw_acf.R --file $TIME_WINDOWS_FILE --output-dir autocorrelation --variable pm2_5;