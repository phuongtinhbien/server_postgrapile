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
	br_id numeric,
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
	select distinct co.id into co_id from customer_order co 
	inner join receipt re on re.order_id = co.id 
	left join wash_bag wb on wb.receipt_id = re.id
	left join wash w on w.wash_bag_id = wb.id
	where w.washing_machine_id = washer_id and w.status = 'SERVING';
	delete from wash where washing_machine_id = washer_id and status in('SERVING','PENDING_SERVING') ;
	delete from wash where washing_machine_id in (select id from washing_machine where status = 'ACTIVE' and branch_id = br_id)
	and status = 'PENDING_SERVING';
	if co_id IS NULL then
	else
		PERFORM updatestatuscustomerorder (co_id, 'PENDING_SERVING',curr_user );
	end if;
	select * into wash from washing_machine where id = washer_id;
	return wash;
end;

$BODY$;


ALTER FUNCTION public.update_serving_wash(
	br_id numeric,
	curr_user numeric,
	washer_id numeric)
    OWNER TO postgres;

GRANT EXECUTE ON FUNCTION public.update_serving_wash(
	br_id numeric,
	curr_user numeric,
	washer_id numeric) TO postgres;

GRANT EXECUTE ON FUNCTION public.update_serving_wash(
	br_id numeric,
	curr_user numeric,
	washer_id numeric) TO PUBLIC;

GRANT EXECUTE ON FUNCTION public.update_serving_wash(
	br_id numeric,
	curr_user numeric,
	washer_id numeric) TO auth_authenticated WITH GRANT OPTION;


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
	washer_list info_washer;
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
	begin
		PERFORM  updatestatuscustomerorder (r.order_id,'PENDING_SERVING',p_user );
		PERFORM assign_auto_wash (branch, r.create_by);
		select * into washer_list from get_info_washer(branch) where sum = (select min(sum) from get_info_washer(branch));
		PERFORM assign_to_wash (r.id, r.create_by, washer_list.id);
	end;
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

--20/11/2018
-- FUNCTION: public.get_min_time_for_handle(numeric)

-- DROP FUNCTION public.get_min_time_for_handle(numeric);

CREATE OR REPLACE FUNCTION public.get_min_time_for_handle(
	br_id numeric)
    RETURNS timestamp without time zone
    LANGUAGE 'sql'

    COST 100
    STABLE 
AS $BODY$

select case when date_part('hour', min_time.max_time_for_handle) > (select value_key::INTEGER from env_var where key_name = 'TIME_END')
or date_part('hour', min_time.max_time_for_handle)< (select value_key::INTEGER from env_var where key_name = 'TIME_START')
then
	min_time.max_time_for_handle + interval '12 hours'
else 
	min_time.max_time_for_handle
end
as max_time_for_handle
from 
  (select case when min(sum) = 0 then
		 	(LOCALTIMESTAMP + (select value_key::INTERVAL as process_time from env_var where key_name = 'TIME_PROCESS'))
			else
				(LOCALTIMESTAMP + min(sum) * (select value_key::INTERVAL as process_time from env_var where key_name = 'TIME_PROCESS') + 
				(select value_key::INTERVAL as process_time from env_var where key_name = 'TIME_PROCESS'))
			end
  as max_time_for_handle from get_info_washer(2) )as min_time
$BODY$;

ALTER FUNCTION public.get_min_time_for_handle(numeric)
    OWNER TO postgres;


--23/11/2018
-- FUNCTION: public.searchcustomerorders(character varying, numeric, numeric)

-- DROP FUNCTION public.searchcustomerorders(character varying, numeric, numeric);

CREATE OR REPLACE FUNCTION public.searchcustomerorders(
	customer_name character varying,
	customer_order numeric,
	branch numeric)
    RETURNS SETOF customer_order 
    LANGUAGE 'sql'

    COST 100
    VOLATILE 
    ROWS 1000
AS $BODY$

	select co.* from customer_order co left join customer cus on cus.id = co.customer_id
	where (unaccent(UPPER(cus.full_name)) ilike  '%'||unaccent(UPPER(customer_name))||'%' or customer_name is null)
	and ( co.id = customer_order or customer_order is null)
	and co.branch_id = branch;

 
$BODY$;

ALTER FUNCTION public.searchcustomerorders(character varying, numeric, numeric)
    OWNER TO postgres;


--24/11/2018
-- FUNCTION: auth_public.register_user(text, text, text, text, text)

-- DROP FUNCTION auth_public.register_user(text, text, text, text, text);

CREATE OR REPLACE FUNCTION auth_public.register_user(
	first_name text,
	last_name text,
	email text,
	user_type text,
	password text)
    RETURNS auth_public."user"
    LANGUAGE 'plpgsql'

    COST 100
    VOLATILE STRICT SECURITY DEFINER 
AS $BODY$
 
DECLARE 
  new_user auth_public.user;
  avai_user Integer; 
BEGIN

    if user_type = 'customer_type'
            then
        SELECT a.id INTO avai_user  FROM public.customer as a  WHERE a.email = $3;        
        ELSEIF user_type = 'staff_type' then 
        SELECT a.id INTO avai_user  FROM public.staff as a  WHERE a.email = $3;  
    end if;
	if user_type = 'admin' then
	select a.id into avai_user from public.admin_account as a where a.username = $3;
	end if;

    if avai_user is null then
    INSERT INTO auth_public.user (first_name, last_name,user_type) values 
        (first_name, last_name,user_type) 
        returning * INTO new_user; 
        if user_type = 'customer_type'
            then
                INSERT INTO public.customer (id, email, password) values (new_user.id, email, crypt(password, gen_salt('bf')));
        ELSEIF user_type = 'staff_type'
            then INSERT INTO public.staff (id, email, password) values (new_user.id, email, crypt(password, gen_salt('bf')));
		elseif user_type = 'admin' then
			INSERT INTO public.admin_account (id, username, full_name,password) values (new_user.id, email,last_name || ' ' || first_name, crypt(password, gen_salt('bf')));
        end if;
    end if;
	
    if new_user is not null then
        return new_user;
    else
        return null;
    end if; 
END; 

$BODY$;

ALTER FUNCTION auth_public.register_user(text, text, text, text, text)
    OWNER TO postgres;

GRANT EXECUTE ON FUNCTION auth_public.register_user(text, text, text, text, text) TO postgres;

GRANT EXECUTE ON FUNCTION auth_public.register_user(text, text, text, text, text) TO PUBLIC;

GRANT EXECUTE ON FUNCTION auth_public.register_user(text, text, text, text, text) TO auth_authenticated;

GRANT EXECUTE ON FUNCTION auth_public.register_user(text, text, text, text, text) TO auth_anonymous;

-- FUNCTION: auth_public.authenticate(text, text, text)

-- DROP FUNCTION auth_public.authenticate(text, text, text);

CREATE OR REPLACE FUNCTION auth_public.authenticate(
	email text,
	password text,
	user_type text)
    RETURNS auth_public.jwt
    LANGUAGE 'plpgsql'

    COST 100
    VOLATILE STRICT SECURITY DEFINER 
AS $BODY$
 
DECLARE 
  account public.customer; 
  ad public.admin_account;
BEGIN
    if user_type = 'customer_type' then
        SELECT a.* INTO account 
        FROM public.customer as a 
        WHERE a.email = $1;
    elseif user_type= 'staff_type' then
        SELECT a.* INTO account 
        FROM public.staff as a 
        WHERE a.email = $1;
	elseif user_type= 'admin'
	then 
	begin
		select a.* into ad from public.admin_account as a where a.username = $1;
		if ad.password = crypt(password,ad.password) then
			return ('auth_authenticated', ad.id,user_type )::auth_public.jwt; 
		end if;
	end;
    end if;
	  if account.password = crypt(password, account.password) then 
		return ('auth_authenticated', account.id,user_type )::auth_public.jwt; 
	  else 
		return null; 
	  end if; 
END; 

$BODY$;

ALTER FUNCTION auth_public.authenticate(text, text, text)
    OWNER TO postgres;

GRANT EXECUTE ON FUNCTION auth_public.authenticate(text, text, text) TO postgres;

GRANT EXECUTE ON FUNCTION auth_public.authenticate(text, text, text) TO PUBLIC;

GRANT EXECUTE ON FUNCTION auth_public.authenticate(text, text, text) TO auth_authenticated;

GRANT EXECUTE ON FUNCTION auth_public.authenticate(text, text, text) TO auth_anonymous;

--25/11/2018
CREATE OR REPLACE FUNCTION updateServiceBranch() RETURNS TRIGGER AS $service_tmp$
   BEGIN
     update service_type_branch set status = NEW.status where service_type_id = NEW.id;
      RETURN NEW;
   END;
$service_tmp$ LANGUAGE plpgsql;

CREATE TRIGGER update_trigger AFTER UPDATE ON service_type
FOR EACH ROW EXECUTE PROCEDURE updateServiceBranch();
--------------------------------
CREATE OR REPLACE FUNCTION updatebranchServiceBranch() RETURNS TRIGGER AS $branch_tmp$
   BEGIN
     update service_type_branch set status = NEW.status where branch_id = NEW.id;
      RETURN NEW;
   END;
$branch_tmp$ LANGUAGE plpgsql;

CREATE TRIGGER update_branch_trigger AFTER UPDATE ON branch
FOR EACH ROW EXECUTE PROCEDURE updatebranchServiceBranch();

-----------------------
CREATE OR REPLACE FUNCTION updatePromotionBranch() RETURNS TRIGGER AS $promotion_tmp$
   BEGIN
     update promotion_branch set status = NEW.status where branch_id = NEW.id;
      RETURN NEW;
   END;
$promotion_tmp$ LANGUAGE plpgsql;

CREATE TRIGGER update_promotion_branch_trigger AFTER UPDATE ON branch
FOR EACH ROW EXECUTE PROCEDURE updatePromotionBranch();

--------------------------------------------
CREATE OR REPLACE FUNCTION updatePromotion() RETURNS TRIGGER AS $promotion_tmp$
   BEGIN
     update promotion_branch set status = NEW.status where promotion_id = NEW.id;
      RETURN NEW;
   END;
$promotion_tmp$ LANGUAGE plpgsql;

CREATE TRIGGER update_promotion_trigger AFTER UPDATE ON promotion
FOR EACH ROW EXECUTE PROCEDURE updatePromotion();

--------------------
-- FUNCTION: public.create_new_branch(branch, numeric[], numeric[], numeric[], numeric[])

-- DROP FUNCTION public.create_new_branch(branch, numeric[], numeric[], numeric[], numeric[]);

CREATE OR REPLACE FUNCTION public.create_new_branch(
	b branch,
	service_type numeric[],
	staff_one numeric[],
	staff_two numeric[],
	staff_three numeric[])
    RETURNS branch
    LANGUAGE 'plpgsql'

    COST 100
    VOLATILE 
AS $BODY$

declare
  bra branch;
  i numeric;
  ser numeric;
begin
  i = nextval('branch_seq');
  b.id = i;
  insert into branch values (b.*);
  foreach ser in array service_type loop
  insert into service_branch (service_type_id, branch_id, status)
  values (ser, i, 'ACTIVE');
  end loop;
  
	update staff set branch_id = i where id = ANY(staff_one);
	update staff set branch_id = i where id = ANY(staff_two);
	update staff set branch_id = i where id = ANY(staff_three);
  select * into bra from branch where id = i;
  return bra;
end;

$BODY$;

ALTER FUNCTION public.create_new_branch(branch, numeric[], numeric[], numeric[], numeric[])
    OWNER TO postgres;

GRANT EXECUTE ON FUNCTION public.create_new_branch(branch, numeric[], numeric[], numeric[], numeric[]) TO postgres;

GRANT EXECUTE ON FUNCTION public.create_new_branch(branch, numeric[], numeric[], numeric[], numeric[]) TO PUBLIC;

GRANT EXECUTE ON FUNCTION public.create_new_branch(branch, numeric[], numeric[], numeric[], numeric[]) TO auth_authenticated WITH GRANT OPTION;





--27/11/2018
-- FUNCTION: public.get_notification_customer(numeric)

-- DROP FUNCTION public.get_notification_customer(numeric);

CREATE OR REPLACE FUNCTION public.get_notification_customer(
	cus_id numeric)
    RETURNS SETOF task 
    LANGUAGE 'sql'

    COST 100
    STABLE 
    ROWS 1000
AS $BODY$

	select a.* from (
        (select t.* from task t inner join customer_order co on co.id = t.customer_order
        inner join customer cu on cu.id = co.customer_id where t.task_type = 'TASK_CUSTOMER_ORDER' and cu.id= cus_id and t.previous_task = 'N')
        UNION
        (select t.* from task t inner join receipt re on t.receipt = re.id
        inner join customer_order co on co.id = re.order_id
        inner join customer cu on cu.id = co.customer_id where t.task_type = 'TASK_RECEIPT' and cu.id= cus_id and t.previous_task = 'N')
    ) as a
 

$BODY$;

ALTER FUNCTION public.get_notification_customer(numeric)
    OWNER TO postgres;

GRANT EXECUTE ON FUNCTION public.get_notification_customer(numeric) TO postgres;

GRANT EXECUTE ON FUNCTION public.get_notification_customer(numeric) TO PUBLIC;

GRANT EXECUTE ON FUNCTION public.get_notification_customer(numeric) TO auth_authenticated;

--28/11/2018
-- FUNCTION: public.create_order_and_detail(customer_order, order_detail[])

-- DROP FUNCTION public.create_order_and_detail(customer_order, order_detail[]);

CREATE OR REPLACE FUNCTION public.update_order_and_detail(
	o customer_order,
	d order_detail[])
    RETURNS customer_order
    LANGUAGE 'plpgsql'

    COST 100
    VOLATILE 
AS $BODY$

declare
	co customer_order;
  i order_detail;
begin
  select * into co from customer_order where id = o.id;
  if co is not null then
  		update customer_order set (update_by, update_date, pick_up_date, pick_up_time_id,
								  delivery_date, delivery_time_id,status)
								  = (o.update_by, o.update_date, o.pick_up_date, o.pick_up_time_id,
								  o.delivery_date, o.delivery_time_id,o.status);
		delete from order_detail where order_id = co.id;
	  foreach i in array d loop
		i.id = nextval('order_detail_seq');
		i.order_id = o.id;
		i.create_date = now();
		i.update_date = now();
		insert into order_detail values (i.*);
	  end loop;
	end if;
	select * into o from customer_order where id = co.id;
  return o;
end;

$BODY$;

ALTER FUNCTION public.update_order_and_detail(customer_order, order_detail[])
    OWNER TO postgres;

GRANT EXECUTE ON FUNCTION public.update_order_and_detail(customer_order, order_detail[]) TO postgres;

GRANT EXECUTE ON FUNCTION public.update_order_and_detail(customer_order, order_detail[]) TO PUBLIC;

GRANT EXECUTE ON FUNCTION public.update_order_and_detail(customer_order, order_detail[]) TO auth_authenticated WITH GRANT OPTION;

--29/11/2018
-- FUNCTION: public.update_service_type_and_unit_price(service_type, unit_price[])

-- DROP FUNCTION public.update_service_type_and_unit_price(service_type, unit_price[]);

CREATE OR REPLACE FUNCTION public.update_service_type_and_unit_price(
	s service_type,
	u unit_price[])
    RETURNS service_type
    LANGUAGE 'plpgsql'

    COST 100
    VOLATILE 
AS $BODY$

declare
	st service_type;
	i unit_price;
begin
	select * into st from service_type where id = s.id;
	if st is null then
	else
	begin
		delete from service_product where service_type_id = st.id;
		update unit_price set status = 'DELETED' where service_type_id = st.id;
		
		  foreach i in array u loop
			i.id = nextval('unit_price_seq');
			i.service_type_id = st.id;
			i.create_date = now();
			i.update_date = now();
			insert into unit_price values (i.*);
			if i.product_id is null then
			else
			insert into service_product (product_id, service_type_id,status)
			values (i.product_id, st.id,'ACTIVE' );
			end if;
		  end loop;
	update service_type set (service_type_name, service_type_desc, status) = (s.service_type_name, s.service_type_desc, s.status) where id = st.id;
		  return st;
	end;
	end if;
  	return st;
end;

$BODY$;

ALTER FUNCTION public.update_service_type_and_unit_price(service_type, unit_price[])
    OWNER TO postgres;

GRANT EXECUTE ON FUNCTION public.update_service_type_and_unit_price(service_type, unit_price[]) TO postgres;

GRANT EXECUTE ON FUNCTION public.update_service_type_and_unit_price(service_type, unit_price[]) TO PUBLIC;

GRANT EXECUTE ON FUNCTION public.update_service_type_and_unit_price(service_type, unit_price[]) TO auth_authenticated WITH GRANT OPTION;

-- FUNCTION: public.create_service_type_and_unit_price(service_type, unit_price[])

-- DROP FUNCTION public.create_service_type_and_unit_price(service_type, unit_price[]);

CREATE OR REPLACE FUNCTION public.create_service_type_and_unit_price(
	s service_type,
	u unit_price[])
    RETURNS service_type
    LANGUAGE 'plpgsql'

    COST 100
    VOLATILE 
AS $BODY$

declare
  i unit_price;
begin
  s.id = nextval('service_type_seq');
  s.create_date = now();
  s.update_date = now();
  insert into service_type values (s.*) returning * into s;
  foreach i in array u loop
    i.id = nextval('unit_price_seq');
    i.service_type_id = s.id;
	i.create_date = now();
  	i.update_date = now();
    insert into unit_price values (i.*);
	
	if i.product_id is null then
	else
	insert into service_product (product_id, service_type_id,status)
	values (i.product_id, s.id,'ACTIVE' );
	end if;
  end loop;
  return s;
end;

$BODY$;

ALTER FUNCTION public.create_service_type_and_unit_price(service_type, unit_price[])
    OWNER TO postgres;

GRANT EXECUTE ON FUNCTION public.create_service_type_and_unit_price(service_type, unit_price[]) TO postgres;

GRANT EXECUTE ON FUNCTION public.create_service_type_and_unit_price(service_type, unit_price[]) TO PUBLIC;

GRANT EXECUTE ON FUNCTION public.create_service_type_and_unit_price(service_type, unit_price[]) TO auth_authenticated WITH GRANT OPTION;



--01/12/2018
-- FUNCTION: public.update_order_and_detail(customer_order, order_detail[])

-- DROP FUNCTION public.update_order_and_detail(customer_order, order_detail[]);

CREATE OR REPLACE FUNCTION public.update_order_and_detail(
	o customer_order,
	d order_detail[])
    RETURNS customer_order
    LANGUAGE 'plpgsql'

    COST 100
    VOLATILE 
AS $BODY$

declare
	co customer_order;
  i order_detail;
begin
  select * into co from customer_order where id = o.id;
  if co is null then
	else
	begin
  		update customer_order set (update_by, update_date, pick_up_date, pick_up_time_id,
								  delivery_date, delivery_time_id,status)
								  = (o.update_by, o.update_date, o.pick_up_date, o.pick_up_time_id,
								  o.delivery_date, o.delivery_time_id,o.status) where id = co.id;
		delete from order_detail where order_id = co.id;
	  foreach i in array d loop
		i.id = nextval('order_detail_seq');
		i.order_id = o.id;
		i.create_date = now();
		i.update_date = now();
		insert into order_detail values (i.*);
	  end loop;
	end;
	end if;
	select * into o from customer_order where id = co.id;
  return o;
end;

$BODY$;

ALTER FUNCTION public.update_order_and_detail(customer_order, order_detail[])
    OWNER TO postgres;

GRANT EXECUTE ON FUNCTION public.update_order_and_detail(customer_order, order_detail[]) TO postgres;

GRANT EXECUTE ON FUNCTION public.update_order_and_detail(customer_order, order_detail[]) TO PUBLIC;

GRANT EXECUTE ON FUNCTION public.update_order_and_detail(customer_order, order_detail[]) TO auth_authenticated WITH GRANT OPTION;



