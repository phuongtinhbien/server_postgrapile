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



--18/11/2018
-- FUNCTION: public.updatestatusreceipt(numeric, character varying, numeric)

-- DROP FUNCTION public.updatestatusreceipt(numeric, character varying, numeric);

CREATE OR REPLACE FUNCTION public.updatestatusreceipt(
	r_id numeric,
	p_status character varying,
	p_user numeric)
    RETURNS receipt
    LANGUAGE 'plpgsql'

    COST 100
    VOLATILE 
AS $BODY$

declare
	no_rec numeric;
	r receipt;
	r_status varchar;
	r_task task;
	branch numeric;
begin
	select re.* into r from receipt re where re.id = r_id;
	select branch_id into branch from customer_order co inner join receipt re on re.order_id = co.id where re.id = r.id;
	r_status := r.status;
	select * into r_task from task where task_type = 'TASK_RECEIPT' and receipt = r_id;
	update task set PREVIOUS_TASK = 'Y' where task_type = 'TASK_RECEIPT' and receipt = r_id;
	update receipt set (status,update_date,update_by) = (p_status, now(),p_user) where id  = r_id;
	update receipt_detail set (status,update_date,update_by) = (p_status, now(),p_user) where receipt_id  = r_id;
	insert into task (current_staff, previous_staff, task_type, customer_order, receipt, previous_status, current_status,PREVIOUS_TASK, branch_id)
		values (p_user, r_task.current_staff, 'TASK_RECEIPT', null,r.id , r_task.current_status, p_status,'N', branch);
	select * into r from receipt  where id = r_id;
	if r.status = 'RECEIVED' then
		PERFORM  updatestatuscustomerorder (r.order_id,'PENDING_SERVING',p_user );
	ELSIF r.status = 'DELIVERIED' then
		PERFORM  updatestatuscustomerorder (r.order_id,'FINISHED',p_user );
		update bill set status ='PAID' where receipt_id = r.id;
		update bill_detail set status = 'PAID' where bill_id = (select id from bill where receipt_id = r.id);
	end if;
  return r;
end;

$BODY$;

ALTER FUNCTION public.updatestatusreceipt(numeric, character varying, numeric)
    OWNER TO postgres;

GRANT EXECUTE ON FUNCTION public.updatestatusreceipt(numeric, character varying, numeric) TO postgres;

GRANT EXECUTE ON FUNCTION public.updatestatusreceipt(numeric, character varying, numeric) TO PUBLIC;

GRANT EXECUTE ON FUNCTION public.updatestatusreceipt(numeric, character varying, numeric) TO auth_authenticated;

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

-- FUNCTION: public.updatereceiptanddetail(receipt, receipt_detail[])

-- DROP FUNCTION public.updatereceiptanddetail(receipt, receipt_detail[]);

CREATE OR REPLACE FUNCTION public.update_Amount_Bill(
	p_b bill,
	bd bill_detail[])
    RETURNS bill
    LANGUAGE 'plpgsql'

    COST 100
    VOLATILE 
AS $BODY$

declare
  i bill_detail;
  b bill;
begin
	select bi.* into b from bill bi where bi.id = p_b.id;

	update bill set (update_by, update_date,status)
	= (p_b.update_by, now(), 'UPDATED');			   

	select bi.* into b from bill bi where bi.id = p_b.id;
  	foreach i in array bd loop
		i.update_date = now();
		update bill_detail set (status,amount, update_by, update_date)
		= ('UPDATED',i.amount,i.update_by,i.update_date) where id = i.id;
  	end loop;
  return r;
end;

$BODY$;

ALTER FUNCTION public.update_Amount_Bill(
	p_b bill,
	bd bill_detail[])
    OWNER TO postgres;

GRANT EXECUTE ON FUNCTION public.update_Amount_Bill(
	p_b bill,
	bd bill_detail[]) TO postgres;

GRANT EXECUTE ON FUNCTION public.update_Amount_Bill(
	p_b bill,
	bd bill_detail[]) TO PUBLIC;

GRANT EXECUTE ON FUNCTION public.update_Amount_Bill(
	p_b bill,
	bd bill_detail[]) TO auth_authenticated;

--19/12/2018
ALTER FUNCTION public.update_wash(numeric, character varying, numeric)
    RENAME TO update_status_wash;

-- FUNCTION: public.assign_to_wash(numeric, numeric, numeric)

-- DROP FUNCTION public.assign_to_wash(numeric, numeric, numeric);

CREATE OR REPLACE FUNCTION public.update_serving_wash(
	curr_user numeric,
	washer_id numeric)
    RETURNS washing_machine
    LANGUAGE 'plpgsql'

    COST 100
    VOLATILE 
AS $BODY$

declare
	wash washing_machine;
	co_id numeric;
begin
	select distinct id into co_id from customer_order co 
	inner join receipt re on re.id = co.id 
	left join wash_bag wb on wb.receipt_id = re.id
	left join wash w on w.wash_bag_id = wb.id
	where w.washing_machine = washer_id and w.status = 'SERVING';
	update wash set (update_by, status,update_date) = (curr_user, 'PENDING_SERVING', now())
	where washing_machine_id = washer_id and status = 'SERVING';
	
	if co_id is not null then
		PERFORM updatestatuscustomerorder (co_id, 'PENDING_SERVING',curr_user );
	end if;
	select * into wash where id = washer_id;
	return wash;
end;

$BODY$;

ALTER FUNCTION public.update_serving_wash(
	curr_user numeric,
	washer_id numeric)
    OWNER TO postgres;

GRANT EXECUTE ON FUNCTION public.update_serving_wash(
	curr_user numeric,
	washer_id numeric) TO postgres;

GRANT EXECUTE ON FUNCTION public.update_serving_wash(
	curr_user numeric,
	washer_id numeric) TO PUBLIC;

GRANT EXECUTE ON FUNCTION public.update_serving_wash(
	curr_user numeric,
	washer_id numeric) TO auth_authenticated WITH GRANT OPTION;

