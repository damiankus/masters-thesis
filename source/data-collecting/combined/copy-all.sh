#!/usr/bin/env bash

pg_dump -d airly -t airly_stations | psql -d pollution
pg_dump -d airly -t airly_observations | psql -d pollution
pg_dump -d airy -t airy_stations | psql -d pollution
pg_dump -d airy -t airy_observations | psql -d pollution
pg_dump -d looko2 -t looko2_stations | psql -d pollution
pg_dump -d looko2 -t looko2_observations | psql -d pollution
pg_dump -d agh-meteo -t meteo_observations | psql -d pollution

