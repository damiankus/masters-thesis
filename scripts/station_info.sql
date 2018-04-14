select * from air_quality_distance;

select station_id, count(*)
from observations
group by 1
order by 2 desc;


select * from observations 
where station_id = 'airly_181';