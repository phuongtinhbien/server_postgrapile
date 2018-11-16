--17/11/2018
-- FUNCTION: public.get_min_time_for_handle(numeric)

-- DROP FUNCTION public.get_min_time_for_handle(numeric);

CREATE OR REPLACE FUNCTION public.get_min_time_for_handle(
	br_id numeric)
    RETURNS timestamp without time zone
    LANGUAGE 'sql'

    COST 100
    STABLE 
AS $BODY$

select case when date_part('hour', min_time.max_time_for_handle) > 17 and date_part('hour', min_time.max_time_for_handle)< 9
then
	min_time.max_time_for_handle + interval '23 hours'
else 
	min_time.max_time_for_handle
end
as max_time_for_handle
from 
  (select case when max(sum) = 0 then
		 	(LOCALTIMESTAMP + interval '5 hour')
			else
				(LOCALTIMESTAMP + max(sum) * interval '5 hour')
			end
  as max_time_for_handle from get_info_washer(br_id) )as min_time

$BODY$;

ALTER FUNCTION public.get_min_time_for_handle(numeric)
    OWNER TO postgres;
