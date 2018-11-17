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

select case when date_part('hour', min_time.max_time_for_handle) > 17 or date_part('hour', min_time.max_time_for_handle)< 6
then
	min_time.max_time_for_handle + interval '12 hours'
else 
	min_time.max_time_for_handle
end
as max_time_for_handle
from 
  (select case when min(sum) = 0 then
		 	(LOCALTIMESTAMP + interval '5 hour')
			else
				(LOCALTIMESTAMP + min(sum) * interval '5 hour')
			end
  as max_time_for_handle from get_info_washer(br_id) )as min_time

$BODY$;

ALTER FUNCTION public.get_min_time_for_handle(numeric)
    OWNER TO postgres;

-- FUNCTION: public.generate_bill(numeric, numeric)

-- DROP FUNCTION public.generate_bill(numeric, numeric);

CREATE OR REPLACE FUNCTION public.generate_bill(
	co_id numeric,
	curr_user numeric)
    RETURNS bill
    LANGUAGE 'plpgsql'

    COST 100
    VOLATILE 
AS $BODY$

declare
  re receipt;
  rd receipt_detail;
  new_bill_id numeric;
  wb_id numeric[];
  i numeric;
  co customer_order;
  res bill;
begin
	select * into co from customer_order where id = co_id;
	select * into re from receipt where order_id = co.id;
	new_bill_id = nextVal('bill_seq');
	
	insert into bill (id, receipt_id, create_by, update_by, status)
	values (new_bill_id, re.id,curr_user,curr_user,'PENDING_PAYING');
	
	foreach i in array ARRAY(select id from receipt_detail where receipt_id = re.id) loop
	begin
	select * into rd from receipt_detail where id = i;
	insert into bill_detail(bill_id, service_type_id, unit_id,unit_price, label_id, color_id, 
						   product_id, material_id,recieved_amount, create_by, update_by, status)
	values (new_bill_id, rd.service_type_id, rd.unit_id, rd.unit_price, rd.label_id, rd.color_id, 
			rd.product_id, rd.material_id,rd.recieved_amount, curr_user,curr_user , 'PENDING_PAYING');
	end;
	end loop;
	select * into res from bill where receipt_id = re.id;
  return res;
end;

$BODY$;

ALTER FUNCTION public.generate_bill(numeric, numeric)
    OWNER TO postgres;

GRANT EXECUTE ON FUNCTION public.generate_bill(numeric, numeric) TO postgres;

GRANT EXECUTE ON FUNCTION public.generate_bill(numeric, numeric) TO PUBLIC;

GRANT EXECUTE ON FUNCTION public.generate_bill(numeric, numeric) TO auth_authenticated;

