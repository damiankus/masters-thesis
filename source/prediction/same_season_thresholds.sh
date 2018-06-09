#!/bin/bash -l
#SBATCH -J SameSeasonNeuralThresholds
#SBATCH -n 12
#SBATCH --mem 8
#SBATCH --time=24:00:00
#SBATCH -A plgdamiankus2018a
#SBATCH -p plgrid
#SBATCH --output="SameSeasonNeuralThresholds.log" 
#SBATCH --mail-type=ALL
#SBATCH --mail-user=dakus@student.agh.edu.pl

module load plgrid/apps/r/3.3.0
R CMD BATCH verify_model_same_season.r SameSeasonNeuralThresholds.log
