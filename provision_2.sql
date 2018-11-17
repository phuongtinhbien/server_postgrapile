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

--18/11/2018
-- FUNCTION: public.sorted_order_list(numeric)

-- DROP FUNCTION public.sorted_order_list(numeric);

CREATE OR REPLACE FUNCTION public.sorted_order_list(
	br_id numeric)
    RETURNS SETOF customer_order 
    LANGUAGE 'sql'

    COST 100
    STABLE 
    ROWS 1000
AS $BODY$

 select co.* from customer_order co
	where co.branch_id = br_id  and co.status = 'PENDING_SERVING' 
	and co.id not in (select distinct co.id from receipt re inner join customer_order co on co.id = re.order_id
							inner join wash_bag wb on re.id = wb.receipt_id
							left join wash w on w.wash_bag_id = wb.id
							inner join washing_machine wm on wm.id = w.washing_machine_id
							where co.branch_id =  2 and co.status in  ('PENDING_SERVING','SERVING') and wm.status ='ACTIVE')
	order by co.delivery_date ASC, co.delivery_time_id ASC

$BODY$;

ALTER FUNCTION public.sorted_order_list(numeric)
    OWNER TO postgres;
-- FUNCTION: public.assign_to_wash(numeric, numeric, numeric)

-- DROP FUNCTION public.assign_to_wash(numeric, numeric, numeric);

CREATE OR REPLACE FUNCTION public.assign_to_wash(
	re_id numeric,
	curr_user numeric,
	washer_id numeric)
    RETURNS receipt
    LANGUAGE 'plpgsql'

    COST 100
    VOLATILE 
AS $BODY$

declare
	wb_list numeric[];
	i numeric;
	r receipt;
	coun numeric;
	sn_max integer;
begin
	wb_list = ARRAY(select id from wash_bag where receipt_id = re_id);
	select count(*) into coun from wash where wash_bag_id in (select id from wash_bag where receipt_id = re_id) and status != 'PENDING_SERVING';
	if coun = 0 then
	begin
		delete from wash where wash_bag_id in (select id from wash_bag where receipt_id = re_id) and status = 'PENDING_SERVING';
		select max(sn) into sn_max from wash where washing_machine_id = washer_id and status = 'PENDING_SERVING';
		if sn_max is null then
			sn_max = 0;
		end if;
		foreach i in array wb_list loop
			insert into wash (wash_bag_id, washing_machine_id, create_by, update_by, status,sn)
			values (i,washer_id,curr_user,curr_user,'PENDING_SERVING',sn_max + 1);
		end loop;
		select * into r from receipt where id = re_id;
		return r;
	end;
	end if;
	return null;
end;

$BODY$;

ALTER FUNCTION public.assign_to_wash(numeric, numeric, numeric)
    OWNER TO postgres;

GRANT EXECUTE ON FUNCTION public.assign_to_wash(numeric, numeric, numeric) TO postgres;

GRANT EXECUTE ON FUNCTION public.assign_to_wash(numeric, numeric, numeric) TO PUBLIC;

GRANT EXECUTE ON FUNCTION public.assign_to_wash(numeric, numeric, numeric) TO auth_authenticated WITH GRANT OPTION;



