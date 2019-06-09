#!/usr/bin/env bash

RESULT_DIR="results-for-thesis"
PLOT_DIR="$RESULT_DIR/plots"

rm -r $RESULT_DIR
mkdir $RESULT_DIR
mkdir $PLOT_DIR

cp -r tables $RESULT_DIR
cp -r plots/accurracy $PLOT_DIR

mkdir $PLOT_DIR/comparison
cp plots/comparison/*__test__*.png $PLOT_DIR/comparison
cp plots/comparison/first-week/comparison__test__gios_bulwarowa__svr__2__.png  $PLOT_DIR/comparison/good_fit__test__gios_bulwarowa__svr__2__.png
cp plots/comparison/first-week/comparison__validation__gios_bulwarowa__svr__1__.png  $PLOT_DIR/comparison/bad_fit__comparison__validation__gios_bulwarowa__svr__1__.png

mkdir $PLOT_DIR/training_history
cp plots/training-history/history__neural_network__hidden=15__activation=relu__epochs=100__min_delta=1e-04__patience_ratio=0.25__batch_size=32__learning_rate=0.1__epsilon=1e-08__l2=0.1__split_id=4@gios_bujaka@2019-05-29_17:54:14@dataset_4__test__season_and_year__.png  $PLOT_DIR/training_history/no_fit.png
cp plots/training-history/history__neural_network__hidden=20-10-5-3__activation=relu__epochs=100__min_delta=1e-04__patience_ratio=0.25__batch_size=32__learning_rate=0.001__epsilon=1e-05__l2=0.001@gios_bujaka@2019-05-21_06:00:46@dataset_2__validation__season_and_year__.png  $PLOT_DIR/training_history/over_fit.png
cp plots/training-history/history__neural_network__hidden=10__activation=relu__epochs=100__min_delta=1e-04__patience_ratio=0.25__batch_size=32__learning_rate=1e-04__epsilon=1e-06__l2=1@gios_krasinskiego@2019-05-30_08:21:03@dataset_1__test__year__.png  $PLOT_DIR/training_history/good_fit.png

echo "DONE!"