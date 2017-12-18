﻿DROP TABLE observations;
CREATE TABLE observations (
    id SERIAL PRIMARY KEY,
    time TIMESTAMP,
    sn_hour_avg NUMERIC(7,2),
    sn_hour_max NUMERIC(7,2),
    sn_hour_min NUMERIC(7,2),
    sm_hour_avg NUMERIC(7,2),
    sm_hour_max NUMERIC(7,2),
    sm_hour_min NUMERIC(7,2),
    sx_hour_avg NUMERIC(7,2),
    sx_hour_max NUMERIC(7,2),
    sx_hour_min NUMERIC(7,2),
    dn_hour_avg NUMERIC(7,2),
    dn_hour_max NUMERIC(7,2),
    dn_hour_min NUMERIC(7,2),
    dm_hour_avg NUMERIC(7,2),
    dm_hour_max NUMERIC(7,2),
    dm_hour_min NUMERIC(7,2),
    dx_hour_avg NUMERIC(7,2),
    dx_hour_max NUMERIC(7,2),
    dx_hour_min NUMERIC(7,2),
    ta_hour_avg NUMERIC(7,2),
    ta_hour_max NUMERIC(7,2),
    ta_hour_min NUMERIC(7,2),
    pa_hour_avg NUMERIC(7,2),
    pa_hour_max NUMERIC(7,2),
    pa_hour_min NUMERIC(7,2),
    tp_hour_avg NUMERIC(7,2),
    tp_hour_max NUMERIC(7,2),
    tp_hour_min NUMERIC(7,2),
    ua_hour_avg NUMERIC(7,2),
    ua_hour_max NUMERIC(7,2),
    ua_hour_min NUMERIC(7,2),
    rc_hour_avg NUMERIC(7,2),
    rc_hour_max NUMERIC(7,2),
    rc_hour_min NUMERIC(7,2),
    rd_hour_avg NUMERIC(7,2),
    rd_hour_max NUMERIC(7,2),
    rd_hour_min NUMERIC(7,2),
    ri_hour_avg NUMERIC(7,2),
    ri_hour_max NUMERIC(7,2),
    ri_hour_min NUMERIC(7,2),
    rp_hour_avg NUMERIC(7,2),
    rp_hour_max NUMERIC(7,2),
    rp_hour_min NUMERIC(7,2),
    hc_hour_avg NUMERIC(7,2),
    hc_hour_max NUMERIC(7,2),
    hc_hour_min NUMERIC(7,2),
    hd_hour_avg NUMERIC(7,2),
    hd_hour_max NUMERIC(7,2),
    hd_hour_min NUMERIC(7,2),
    hi_hour_avg NUMERIC(7,2),
    hi_hour_max NUMERIC(7,2),
    hi_hour_min NUMERIC(7,2),
    hp_hour_avg NUMERIC(7,2),
    hp_hour_max NUMERIC(7,2),
    hp_hour_min NUMERIC(7,2),
    odew_hour_avg NUMERIC(7,2),
    odew_hour_max NUMERIC(7,2),
    odew_hour_min NUMERIC(7,2),
    barosealevel_hour_avg NUMERIC(7,2),
    barosealevel_hour_max NUMERIC(7,2),
    barosealevel_hour_min NUMERIC(7,2)
);
\copy observations (time, sn_hour_avg, sn_hour_max, sn_hour_min, sm_hour_avg, sm_hour_max, sm_hour_min, sx_hour_avg, sx_hour_max, sx_hour_min, dn_hour_avg, dn_hour_max, dn_hour_min, dm_hour_avg, dm_hour_max, dm_hour_min, dx_hour_avg, dx_hour_max, dx_hour_min, ta_hour_avg, ta_hour_max, ta_hour_min, pa_hour_avg, pa_hour_max, pa_hour_min, tp_hour_avg, tp_hour_max, tp_hour_min, ua_hour_avg, ua_hour_max, ua_hour_min, rc_hour_avg, rc_hour_max, rc_hour_min, rd_hour_avg, rd_hour_max, rd_hour_min, ri_hour_avg, ri_hour_max, ri_hour_min, rp_hour_avg, rp_hour_max, rp_hour_min, hc_hour_avg, hc_hour_max, hc_hour_min, hd_hour_avg, hd_hour_max, hd_hour_min, hi_hour_avg, hi_hour_max, hi_hour_min, hp_hour_avg, hp_hour_max, hp_hour_min, odew_hour_avg, odew_hour_max, odew_hour_min, barosealevel_hour_avg, barosealevel_hour_max, barosealevel_hour_min)
FROM meteo_agh.csv WITH HEADER DELIMITER ',' CSV;
SELECT time, sm_hour_avg FROM observations;