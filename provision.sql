
delete from customer;
DROP SCHEMA auth_public;
DROP DATABASE IF EXISTS auth;
DROP ROLE IF EXISTS auth_anonymous;
DROP ROLE IF EXISTS auth_authenticated;
DROP ROLE IF EXISTS auth_postgraphile;

--- 

-- CREATE DATABASE auth;
CREATE EXTENSION IF NOT EXISTS "pgcrypto"; 
CREATE EXTENSION IF NOT EXISTS "citext"; 
CREATE SCHEMA auth_public; 

CREATE ROLE auth_postgraphile LOGIN PASSWORD 'password';
CREATE ROLE auth_anonymous;
GRANT auth_anonymous TO auth_postgraphile;
CREATE ROLE auth_authenticated;
GRANT auth_authenticated TO auth_postgraphile;
CREATE TABLE auth_public.user ( 
	  id              serial primary key, 
	  first_name      text not null check (char_length(first_name) < 80), 
	  last_name       text check (char_length(last_name) < 80),
	  created_at      timestamp default now(),
		user_type		text

);


CREATE TYPE auth_public.jwt as ( 
  role    text, 
  user_id integer,
	user_type text
);

CREATE FUNCTION auth_public.current_user_id() RETURNS INTEGER AS $$
  SELECT current_setting('jwt.claims.user_id', true)::integer;
$$ LANGUAGE SQL STABLE;

ALTER TABLE auth_public.user ENABLE ROW LEVEL SECURITY;

CREATE POLICY select_user ON auth_public.user FOR SELECT
  using(true);

CREATE POLICY update_user ON auth_public.user FOR UPDATE TO auth_authenticated 
  using (id = auth_public.current_user_id());

CREATE POLICY delete_user ON auth_public.user FOR DELETE TO auth_authenticated 
  using (id = auth_public.current_user_id());

CREATE OR REPLACE FUNCTION auth_public.register_user( 
  first_name  text, 
  last_name   text, 
  email       text,
  user_type text,
  password    text

) RETURNS auth_public.user AS $$ 
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

    if avai_user is null then
    INSERT INTO auth_public.user (first_name, last_name,user_type) values 
        (first_name, last_name,user_type) 
        returning * INTO new_user; 
        if user_type = 'customer_type'
            then
                INSERT INTO public.customer (id, email, password) values (new_user.id, email, crypt(password, gen_salt('bf')));
        ELSEIF user_type = 'staff_type'
            then INSERT INTO public.staff (id, email, password) values (new_user.id, email, crypt(password, gen_salt('bf')));
        end if;
    end if;   
    if new_user is not null then
        return new_user;
    else
        return null;
    end if; 
END; 
$$ language plpgsql strict security definer;

CREATE OR REPLACE FUNCTION auth_public.authenticate ( 
  email text, 
  password text,
	user_type text
) returns auth_public.jwt as $$ 
DECLARE 
  account public.customer; 
BEGIN
    if user_type = 'customer_type' then
        SELECT a.* INTO account 
        FROM public.customer as a 
        WHERE a.email = $1;
    elseif user_type= 'staff_type' then
        SELECT a.* INTO account 
        FROM public.staff as a 
        WHERE a.email = $1;
    end if;
  if account.password = crypt(password, account.password) then 
    return ('auth_authenticated', account.id,user_type )::auth_public.jwt; 
  else 
    return null; 
  end if; 
END; 
$$ language plpgsql strict security definer;

CREATE OR REPLACE FUNCTION auth_public.current_user() RETURNS auth_public.user AS $$ 
  SELECT * 
  FROM auth_public.user 
  WHERE id = auth_public.current_user_id()
$$ language sql stable;

GRANT USAGE ON SCHEMA auth_public TO auth_anonymous, auth_authenticated; 
GRANT SELECT ON TABLE auth_public.user TO auth_anonymous, auth_authenticated;
GRANT USAGE ON SCHEMA public TO auth_authenticated; 
GRANT UPDATE, DELETE ON TABLE auth_public.user TO auth_authenticated;																												 
GRANT EXECUTE ON FUNCTION auth_public.authenticate(text, text,text) TO auth_anonymous, auth_authenticated; 
GRANT EXECUTE ON FUNCTION auth_public.register_user(text, text, text, text,text) TO auth_anonymous; 
GRANT EXECUTE ON FUNCTION auth_public.current_user() TO auth_anonymous, auth_authenticated; 

																													 
--Phan quyen
GRANT INSERT, SELECT, UPDATE, REFERENCES, TRIGGER ON TABLE public.bill TO auth_authenticated WITH GRANT OPTION;

GRANT INSERT, SELECT, UPDATE, REFERENCES, TRIGGER ON TABLE public.bill_detail TO auth_authenticated WITH GRANT OPTION;

GRANT INSERT, SELECT, UPDATE, REFERENCES, TRIGGER ON TABLE public.branch TO auth_authenticated WITH GRANT OPTION;

GRANT INSERT, SELECT, UPDATE, REFERENCES, TRIGGER ON TABLE public.color TO auth_authenticated WITH GRANT OPTION;

GRANT INSERT, SELECT, UPDATE, REFERENCES, TRIGGER ON TABLE public.color_group TO auth_authenticated WITH GRANT OPTION;

GRANT INSERT, SELECT, UPDATE, REFERENCES, TRIGGER ON TABLE public.customer TO auth_authenticated WITH GRANT OPTION;

GRANT INSERT, SELECT, UPDATE, REFERENCES, TRIGGER ON TABLE public.customer_order TO auth_authenticated WITH GRANT OPTION;

GRANT INSERT, SELECT, UPDATE, REFERENCES, TRIGGER ON TABLE public.dry TO auth_authenticated WITH GRANT OPTION;

GRANT INSERT, SELECT, UPDATE, REFERENCES, TRIGGER ON TABLE public.dryer TO auth_authenticated WITH GRANT OPTION;

GRANT INSERT, SELECT, UPDATE, REFERENCES, TRIGGER ON TABLE public.label TO auth_authenticated WITH GRANT OPTION;

GRANT INSERT, SELECT, UPDATE, REFERENCES, TRIGGER ON TABLE public.material TO auth_authenticated WITH GRANT OPTION;

GRANT INSERT, SELECT, UPDATE, REFERENCES, TRIGGER ON TABLE public.order_detail TO auth_authenticated WITH GRANT OPTION;

GRANT INSERT, SELECT, UPDATE, REFERENCES, TRIGGER ON TABLE public.payment TO auth_authenticated WITH GRANT OPTION;

GRANT INSERT, SELECT, UPDATE, REFERENCES, TRIGGER ON TABLE public.product TO auth_authenticated WITH GRANT OPTION;

GRANT INSERT, SELECT, UPDATE, REFERENCES, TRIGGER ON TABLE public.product_type TO auth_authenticated WITH GRANT OPTION;

GRANT INSERT, SELECT, UPDATE, REFERENCES, TRIGGER ON TABLE public.promotion TO auth_authenticated WITH GRANT OPTION;

GRANT INSERT, SELECT, UPDATE, REFERENCES, TRIGGER ON TABLE public.promotion_branch TO auth_authenticated WITH GRANT OPTION;

GRANT INSERT, SELECT, UPDATE, REFERENCES, TRIGGER ON TABLE public.receipt TO auth_authenticated WITH GRANT OPTION;

GRANT INSERT, SELECT, UPDATE, REFERENCES, TRIGGER ON TABLE public.receipt_detail TO auth_authenticated WITH GRANT OPTION;

GRANT INSERT, SELECT, UPDATE, REFERENCES, TRIGGER ON TABLE public.receipt_wash_bag TO auth_authenticated WITH GRANT OPTION;

GRANT INSERT, SELECT, UPDATE, REFERENCES, TRIGGER ON TABLE public.service_type TO auth_authenticated WITH GRANT OPTION;

GRANT INSERT, SELECT, UPDATE, REFERENCES, TRIGGER ON TABLE public.service_type_branch TO auth_authenticated WITH GRANT OPTION;

GRANT INSERT, SELECT, UPDATE, REFERENCES, TRIGGER ON TABLE public.staff TO auth_authenticated WITH GRANT OPTION;

GRANT INSERT, SELECT, UPDATE, REFERENCES, TRIGGER ON TABLE public.staff_type TO auth_authenticated WITH GRANT OPTION;

GRANT INSERT, SELECT, UPDATE, REFERENCES, TRIGGER ON TABLE public.store TO auth_authenticated WITH GRANT OPTION;

GRANT INSERT, SELECT, UPDATE, REFERENCES, TRIGGER ON TABLE public.time_schedule TO auth_authenticated WITH GRANT OPTION;

GRANT INSERT, SELECT, UPDATE, REFERENCES, TRIGGER ON TABLE public.unit TO auth_authenticated WITH GRANT OPTION;

GRANT INSERT, SELECT, UPDATE, REFERENCES, TRIGGER ON TABLE public.unit_price TO auth_authenticated WITH GRANT OPTION;

GRANT INSERT, SELECT, UPDATE, REFERENCES, TRIGGER ON TABLE public.wash TO auth_authenticated WITH GRANT OPTION;

GRANT INSERT, SELECT, UPDATE, REFERENCES, TRIGGER ON TABLE public.wash_bag TO auth_authenticated WITH GRANT OPTION;

GRANT INSERT, SELECT, UPDATE, REFERENCES, TRIGGER ON TABLE public.wash_bag_detail TO auth_authenticated WITH GRANT OPTION;

GRANT INSERT, SELECT, UPDATE, REFERENCES, TRIGGER ON TABLE public.washing_machine TO auth_authenticated WITH GRANT OPTION;

GRANT INSERT, SELECT, UPDATE, REFERENCES, TRIGGER ON TABLE public.post TO auth_authenticated WITH GRANT OPTION;

--Insert order and order detail
create or replace function create_order_and_detail(o customer_order, d order_detail[]) returns customer_order as $$
declare
  i order_detail;
begin
  o.id = nextval('customer_order_seq');
  o.create_date = now();
  o.update_date = now();
  o.status = 'PENDING';
  insert into customer_order values (o.*) returning * into o;
  foreach i in array d loop
    i.id = nextval('order_detail_seq');
    i.order_id = o.id;
	  i.create_date = now();
  	i.update_date = now();
    i.status = 'PENDING';
    insert into order_detail values (i.*);
  end loop;
  return o;
end;
$$ language plpgsql volatile;

GRANT EXECUTE ON FUNCTION create_order_and_detail(o customer_order, d order_detail[]) TO auth_authenticated; 
GRANT ALL ON SEQUENCE public.customer_order_seq TO auth_authenticated;
GRANT ALL ON SEQUENCE public.order_detail_seq TO auth_authenticated;

--get amount money order
drop getAmountofOrderByCustomerId(customerId numeric, customerOrder numeric);
create or replace function getAmountofOrderByCustomerId(customerId numeric, customerOrder numeric) returns varchar as $$
declare
  i order_detail;
  amount numeric;
begin
 SELECT SUM(od.amount) into amount from customer cu
 inner join customer_order co on cu.id = co.customer_id
 left join order_detail od on co.id = od.order_id
 where cu.id = customerId and co.id = customerOrder;
 	
  return amount::float8::numeric::money;
end;
$$ language plpgsql volatile;

--GRANt for time_schedule_seq
GRANT ALL ON SEQUENCE public.time_schedule_seq TO auth_authenticated;

-- approved
create or replace function updateStatusCustomerOrder(co_id numeric, p_status varchar, p_user numeric ) returns customer_order as $$
declare
	o customer_order;
	receipt_id numeric;
	no_rec numeric;
begin
	update customer_order co set status = p_status where co.id = co_id;
	update customer_order co set update_date = now() where co.id = co_id;
	update order_detail od set status = p_status where od.order_id = co_id;
	update order_detail od set update_date = now() where od.order_id = co_id;
	select co.*  into o from customer_order co where co.id = co_id;
	if o.status = 'APPROVED' then
	begin
		receipt_id = nextval ('receipt_seq');
		insert into receipt (id, order_id, status, create_by, update_by)
		values (receipt_id,o.id, 'PENDING', p_user,p_user);
		select count(1) into no_rec from order_detail where order_id  = o.id;
		if no_rec> 0 then
		begin
			insert into receipt_detail (
				id, receipt_id, service_type_id, unit_id, label_id,
				color_id, product_id, material_id, amount,create_by, update_by, status)
			select nextval('receipt_detail_seq'),receipt_id, service_type_id, unit_id, label_id,
				color_id, product_id, material_id, amount,p_user, p_user, 'PENDING'
			from order_detail where order_id  = o.id;	
		end;
		end if;
	end;
	end if;
  return o;
end;
$$ language plpgsql volatile;

GRANT EXECUTE ON FUNCTION updateStatusCustomerOrder(co_id numeric, p_status varchar, p_user numeric ) TO auth_authenticated;
GRANT ALL ON SEQUENCE public.receipt_seq TO auth_authenticated;
GRANT ALL ON SEQUENCE public.receipt_detail_seq TO auth_authenticated;
--update recceipt
create or replace function updateReceiptAndDetail (p_re receipt, rd receipt_detail[]) returns receipt as $$
declare
  i receipt_detail;
  r receipt;
begin
	select re.* into r from receipt re where re.id = p_re.id;
  	if r is not null then
		update receipt set (pick_up_time, delivery_time, update_by, update_date, status, pick_up_date,
						   delivery_date, pick_up_place, delivery_place)
		= (p_re.pick_up_time, p_re.delivery_time, p_re.update_by, p_re.update_date, p_re.status, p_re.pick_up_date,
						   p_re.delivery_date, p_re.pick_up_place, p_re.delivery_place);			   
	end if;
	select re.* into r from receipt re where re.id = p_re.id;
  	foreach i in array rd loop
		i.update_date = now();
		i.status = r.status;
		update receipt_detail set (recieved_amount, status,  update_by, update_date)
		= (i.recieved_amount, i.status, i.update_by,i.update_date);
  	end loop;
  return r;
end;
$$ language plpgsql volatile;

GRANT EXECUTE ON FUNCTION updateReceiptAndDetail (p_re receipt, rd receipt_detail[]) TO auth_authenticated; 


--UPDATE FUCNTION
-- FUNCTION: public.updatestatuscustomerorder(numeric, character varying, numeric)

-- DROP FUNCTION public.updatestatuscustomerorder(numeric, character varying, numeric);

CREATE OR REPLACE FUNCTION public.updatestatuscustomerorder(
	co_id numeric,
	p_status character varying,
	p_user numeric)
    RETURNS customer_order
    LANGUAGE 'plpgsql'

    COST 100
    VOLATILE 
AS $BODY$

declare
	o customer_order;
	receipt_id numeric;
	no_rec numeric;
	r receipt;
	co_status varchar;
	task_order task;
begin
	select status into co_status from customer_order co where co.id = co_id;
	update customer_order co set status = p_status where co.id = co_id;
	update customer_order co set update_date = now() where co.id = co_id;
	update order_detail od set status = p_status where od.order_id = co_id;
	update order_detail od set update_date = now() where od.order_id = co_id;
	select co.*  into o from customer_order co where co.id = co_id;
	select * into task_order from task where task_type='TASK_CUSTOMER_ORDER' and customer_order = o.id;
	update task set PREVIOUS_TASK = 'Y' where task_type='TASK_CUSTOMER_ORDER' and customer_order = o.id;
	insert into task (current_staff, previous_staff, task_type, customer_order, receipt, previous_status, current_status,PREVIOUS_TASK)
		values (p_user, task_order.current_staff, 'TASK_CUSTOMER_ORDER', o.id, null, co_status, o.status, 'N');
	if o.status = 'APPROVED' then
		begin
			receipt_id = nextval ('receipt_seq');
			insert into receipt (id, order_id, status, create_by, update_by)
			values (receipt_id,o.id, 'PENDING', p_user,p_user) returning * into r;
			insert into task (current_staff, previous_staff, task_type, customer_order, receipt, previous_status, current_status,PREVIOUS_TASK)
			values (p_user, null, 'TASK_RECEIPT', null,receipt_id , null, r.status,'N');
			select count(1) into no_rec from order_detail where order_id  = o.id;
			if no_rec> 0 then
			begin
				insert into receipt_detail (
					id, receipt_id, service_type_id, unit_id, label_id,
					color_id, product_id, material_id, amount,create_by, update_by, status)
				select nextval('receipt_detail_seq'),receipt_id, service_type_id, unit_id, label_id,
					color_id, product_id, material_id, amount,p_user, p_user, 'PENDING'
				from order_detail where order_id  = o.id;	
			end;
			end if;
		end;
	elsif o.status = 'FINISHED_SERVING' then
		begin
		select * into r from receipt where order_id = o.id;
		PERFORM updatestatusreceipt(r.id,'PENDING_DELIVERY', p_user);
		end;
	end if;
  return o;
end;

$BODY$;

ALTER FUNCTION public.updatestatuscustomerorder(numeric, character varying, numeric)
    OWNER TO postgres;

GRANT EXECUTE ON FUNCTION public.updatestatuscustomerorder(numeric, character varying, numeric) TO postgres;

GRANT EXECUTE ON FUNCTION public.updatestatuscustomerorder(numeric, character varying, numeric) TO PUBLIC;

GRANT EXECUTE ON FUNCTION public.updatestatuscustomerorder(numeric, character varying, numeric) TO auth_authenticated;










GRANT INSERT, SELECT, UPDATE, REFERENCES, TRIGGER ON TABLE public.task TO auth_authenticated WITH GRANT OPTION;

GRANT ALL ON SEQUENCE public.task_id_seq TO auth_authenticated;


--FUNCTION RECEIPT
-- FUNCTION: public.updatestatuscustomerorder(numeric, character varying, numeric)

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
begin
	select re.* into r from receipt re where re.id = r_id;
	r_status := r.status;
	select * into r_task from task where task_type = 'TASK_RECEIPT' and receipt = r_id;
	update task set PREVIOUS_TASK = 'Y' where task_type = 'TASK_RECEIPT' and receipt = r_id;
	update receipt set (status,update_date,update_by) = (p_status, now(),p_user) where id  = r_id;
	insert into task (current_staff, previous_staff, task_type, customer_order, receipt, previous_status, current_status,PREVIOUS_TASK)
		values (p_user, r_task.current_staff, 'TASK_RECEIPT', null,r.id , r_task.current_status, p_status,'N');
	select * into r from receipt  where id = r_id;
	if r.status = 'RECEIVED' then
		PERFORM  updatestatuscustomerorder (r.order_id,'PENDING_SERVING',p_user );
	ELSIF r.status = 'DELIVERIED' then
		PERFORM  updatestatuscustomerorder (r.order_id,'FINISHED',p_user );
	end if;
  return r;
end;

$BODY$;

ALTER FUNCTION public.updatestatusreceipt(numeric, character varying, numeric)
    OWNER TO postgres;

GRANT EXECUTE ON FUNCTION public.updatestatusreceipt(numeric, character varying, numeric) TO postgres;

GRANT EXECUTE ON FUNCTION public.updatestatusreceipt(numeric, character varying, numeric) TO PUBLIC;

GRANT EXECUTE ON FUNCTION public.updatestatusreceipt(numeric, character varying, numeric) TO auth_authenticated;

--27/10/2018

-- FUNCTION: public.updatestatusofcustomerorderlist(numeric[], character varying, numeric)

-- DROP FUNCTION public.updatestatusofcustomerorderlist(numeric[], character varying, numeric);

CREATE OR REPLACE FUNCTION public.updatestatusofcustomerorderlist(
	co_id numeric[],
	p_status character varying,
	p_user numeric)
    RETURNS customer_order[]
    LANGUAGE 'plpgsql'

    COST 100
    VOLATILE 
AS $BODY$

declare
	i numeric;
	res customer_order[];
begin
	foreach i in array co_id loop
		perform updatestatuscustomerorder(i, p_status_p_user);
	end loop;
	select * into res from customer_order where id = co_id;
  return res;
end;

$BODY$;

ALTER FUNCTION public.updatestatusofcustomerorderlist(numeric[], character varying, numeric)
    OWNER TO postgres;



--01/11/2018

-- FUNCTION: public.updatestatuscustomerorder(numeric, character varying, numeric)

-- DROP FUNCTION public.updatestatuscustomerorder(numeric, character varying, numeric);

CREATE OR REPLACE FUNCTION public.updatestatuscustomerorder(
	co_id numeric,
	p_status character varying,
	p_user numeric)
    RETURNS customer_order
    LANGUAGE 'plpgsql'

    COST 100
    VOLATILE 
AS $BODY$

declare
	o customer_order;
	receipt_id numeric;
	no_rec numeric;
	r receipt;
	co_status varchar;
	task_order task;
begin
	select status into co_status from customer_order co where co.id = co_id;
	update customer_order co set status = p_status where co.id = co_id;
	update customer_order co set update_date = now() where co.id = co_id;
	update order_detail od set status = p_status where od.order_id = co_id;
	update order_detail od set update_date = now() where od.order_id = co_id;
	select co.*  into o from customer_order co where co.id = co_id;
	select * into task_order from task where task_type='TASK_CUSTOMER_ORDER' and customer_order = o.id;
	update task set PREVIOUS_TASK = 'Y' where task_type='TASK_CUSTOMER_ORDER' and customer_order = o.id;
	insert into task (current_staff, previous_staff, task_type, customer_order, receipt, previous_status, current_status,PREVIOUS_TASK, branch_id)
		values (p_user, task_order.current_staff, 'TASK_CUSTOMER_ORDER', o.id, null, co_status, o.status, 'N', o.branch_id);
	if o.status = 'APPROVED' then
		begin
			receipt_id = nextval ('receipt_seq');
			insert into receipt (id, order_id, status, create_by, update_by)
			values (receipt_id,o.id, 'PENDING', p_user,p_user) returning * into r;
			insert into task (current_staff, previous_staff, task_type, customer_order, receipt, previous_status, current_status,PREVIOUS_TASK, branch_id)
			values (p_user, null, 'TASK_RECEIPT', null,receipt_id , null, r.status,'N',o.branch_id );
			select count(1) into no_rec from order_detail where order_id  = o.id;
			if no_rec> 0 then
			begin
				insert into receipt_detail (
					id, receipt_id, service_type_id, unit_id, label_id,
					color_id, product_id, material_id, amount,create_by, update_by, status)
				select nextval('receipt_detail_seq'),receipt_id, service_type_id, unit_id, label_id,
					color_id, product_id, material_id, amount,p_user, p_user, 'PENDING'
				from order_detail where order_id  = o.id;	
			end;
			end if;
		end;
	elsif o.status = 'FINISHED_SERVING' then
		begin
		select * into r from receipt where order_id = o.id;
		PERFORM updatestatusreceipt(r.id,'PENDING_DELIVERY', p_user);
		end;
	end if;
  return o;
end;

$BODY$;

ALTER FUNCTION public.updatestatuscustomerorder(numeric, character varying, numeric)
    OWNER TO postgres;

GRANT EXECUTE ON FUNCTION public.updatestatuscustomerorder(numeric, character varying, numeric) TO postgres;

GRANT EXECUTE ON FUNCTION public.updatestatuscustomerorder(numeric, character varying, numeric) TO PUBLIC;

GRANT EXECUTE ON FUNCTION public.updatestatuscustomerorder(numeric, character varying, numeric) TO auth_authenticated;

--Receipt

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
	insert into task (current_staff, previous_staff, task_type, customer_order, receipt, previous_status, current_status,PREVIOUS_TASK, branch_id)
		values (p_user, r_task.current_staff, 'TASK_RECEIPT', null,r.id , r_task.current_status, p_status,'N', branch);
	select * into r from receipt  where id = r_id;
	if r.status = 'RECEIVED' then
		PERFORM  updatestatuscustomerorder (r.order_id,'PENDING_SERVING',p_user );
	ELSIF r.status = 'DELIVERIED' then
		PERFORM  updatestatuscustomerorder (r.order_id,'FINISHED',p_user );
	end if;
  return r;
end;

$BODY$;

ALTER FUNCTION public.updatestatusreceipt(numeric, character varying, numeric)
    OWNER TO postgres;

GRANT EXECUTE ON FUNCTION public.updatestatusreceipt(numeric, character varying, numeric) TO postgres;

GRANT EXECUTE ON FUNCTION public.updatestatusreceipt(numeric, character varying, numeric) TO PUBLIC;

GRANT EXECUTE ON FUNCTION public.updatestatusreceipt(numeric, character varying, numeric) TO auth_authenticated;



--02/11/2018
GRANT ALL ON SEQUENCE public.staff_type_seq TO auth_authenticated;



--03/11/2018
REVOKE ALL ON SEQUENCE auth_public.user_id_seq FROM auth_anonymous;
GRANT ALL ON SEQUENCE auth_public.user_id_seq TO auth_authenticated;

CREATE OR REPLACE FUNCTION public.create_cus_order_and_detail(
	cus customer,
	o customer_order,
	d order_detail[])
    RETURNS customer_order
    LANGUAGE 'plpgsql'

    COST 100
    VOLATILE 
AS $BODY$

declare
  	i order_detail;
	avai_customer customer;
	new_user auth_public.user;
	unit_price numeric;
begin

	select * into avai_customer from customer c where c.email = cus.email;
	o.customer_id = avai_customer.id;
	if avai_customer is null then
	begin
		new_user = auth_public."register_user" (cus.full_name, ' ', cus.email, 'customer_type','password1');
		update customer set (full_name, phone, status, create_by, update_by) = (cus.full_name, cus.phone,true, cus.create_by, cus.update_by) where id = new_user.id;
		o.customer_id = new_user.id;

	end;
	end if;
	
  o.id = nextval('customer_order_seq');
  o.create_date = now();
  o.update_date = now();
	o.status='DRAFT';
  insert into customer_order values (o.*) returning * into o;
	
  foreach i in array d loop
    i.id = nextval('order_detail_seq');
	i.status = 'DRAFT';
	select id into unit_price
	from unit_price
	where product_id = i.product_id
	and service_type_id = i.service_type_id 
	and unit_id = i.unit_id
	and apply_date = (select max(apply_date) from unit_price
	where product_id = i.product_id
	and service_type_id = i.service_type_id 
	and unit_id = i.unit_id
	and status = 'ACTIVE');
	i.unit_price = unit_price;
    i.order_id = o.id;
	i.create_date = now();
  	i.update_date = now();
    insert into order_detail values (i.*);
  end loop;
  return o;
end;

$BODY$;

ALTER FUNCTION public.create_cus_order_and_detail(customer, customer_order, order_detail[])
    OWNER TO postgres;

GRANT EXECUTE ON FUNCTION public.create_cus_order_and_detail(customer, customer_order, order_detail[]) TO postgres;

GRANT EXECUTE ON FUNCTION public.create_cus_order_and_detail(customer, customer_order, order_detail[]) TO PUBLIC;

GRANT EXECUTE ON FUNCTION public.create_cus_order_and_detail(customer, customer_order, order_detail[]) TO auth_authenticated WITH GRANT OPTION;

CREATE POLICY insert_user ON auth_public.user FOR UPDATE TO auth_authenticated 
  with check (id in (select st.id from staff st inner join staff_type stp on stp.id = st.staff_type_id where stp.staff_code ='STAFF_01') and id = auth_public.current_user_id());


 --update recieved amount khi nhan do

-- FUNCTION: public.updatereceiptanddetail(receipt, receipt_detail[])

-- DROP FUNCTION public.updatereceiptanddetail(receipt, receipt_detail[]);

CREATE OR REPLACE FUNCTION public.updatereceiptanddetail(
	p_re receipt,
	rd receipt_detail[])
    RETURNS receipt
    LANGUAGE 'plpgsql'

    COST 100
    VOLATILE 
AS $BODY$

declare
  i receipt_detail;
  r receipt;
begin
	select re.* into r from receipt re where re.id = p_re.id;

	update receipt set (pick_up_time, delivery_time, update_by, update_date,  pick_up_date,
					   delivery_date, pick_up_place, delivery_place)
	= (p_re.pick_up_time, p_re.delivery_time, p_re.update_by, p_re.update_date,  p_re.pick_up_date,
					   p_re.delivery_date, p_re.pick_up_place, p_re.delivery_place);			   

	select re.* into r from receipt re where re.id = p_re.id;
  	foreach i in array rd loop
		i.update_date = now();
		update receipt_detail set (recieved_amount,  update_by, update_date)
		= (i.recieved_amount, i.update_by,i.update_date) where id = i.id;
  	end loop;
  return r;
end;

$BODY$;

ALTER FUNCTION public.updatereceiptanddetail(receipt, receipt_detail[])
    OWNER TO postgres;

GRANT EXECUTE ON FUNCTION public.updatereceiptanddetail(receipt, receipt_detail[]) TO postgres;

GRANT EXECUTE ON FUNCTION public.updatereceiptanddetail(receipt, receipt_detail[]) TO PUBLIC;

GRANT EXECUTE ON FUNCTION public.updatereceiptanddetail(receipt, receipt_detail[]) TO auth_authenticated;


-- 04/11/2018
-- FUNCTION: public.updatestatuscustomerorder(numeric, character varying, numeric)

-- DROP FUNCTION public.updatestatuscustomerorder(numeric, character varying, numeric);

CREATE OR REPLACE FUNCTION public.updatestatuscustomerorder(
	co_id numeric,
	p_status character varying,
	p_user numeric)
    RETURNS customer_order
    LANGUAGE 'plpgsql'

    COST 100
    VOLATILE 
AS $BODY$

declare
	o customer_order;
	receipt_id numeric;
	no_rec numeric;
	r receipt;
	co_status varchar;
	task_order task;
begin
	select status into co_status from customer_order co where co.id = co_id;
	update customer_order co set status = p_status where co.id = co_id;
	update customer_order co set update_date = now() where co.id = co_id;
	update order_detail od set status = p_status where od.order_id = co_id;
	update order_detail od set update_date = now() where od.order_id = co_id;
	select co.*  into o from customer_order co where co.id = co_id;
	select * into task_order from task where task_type='TASK_CUSTOMER_ORDER' and customer_order = o.id;
	update task set PREVIOUS_TASK = 'Y' where task_type='TASK_CUSTOMER_ORDER' and customer_order = o.id;
	insert into task (current_staff, previous_staff, task_type, customer_order, receipt, previous_status, current_status,PREVIOUS_TASK, branch_id)
		values (p_user, task_order.current_staff, 'TASK_CUSTOMER_ORDER', o.id, null, co_status, o.status, 'N', o.branch_id);
	if o.status = 'APPROVED' then
		begin
			receipt_id = nextval ('receipt_seq');
			insert into receipt (id, order_id, status, create_by, update_by)
			values (receipt_id,o.id, 'PENDING', p_user,p_user) returning * into r;
			insert into task (current_staff, previous_staff, task_type, customer_order, receipt, previous_status, current_status,PREVIOUS_TASK, branch_id)
			values (p_user, null, 'TASK_RECEIPT', null,receipt_id , null, r.status,'N',o.branch_id );
			select count(1) into no_rec from order_detail where order_id  = o.id;
			if no_rec> 0 then
			begin
				insert into receipt_detail (
					id, receipt_id, service_type_id, unit_id, label_id,
					color_id, product_id, material_id, amount,create_by, update_by, status,unit_price)
				select nextval('receipt_detail_seq'),receipt_id, service_type_id, unit_id, label_id,
					color_id, product_id, material_id, amount,p_user, p_user, 'PENDING', unit_price
				from order_detail where order_id  = o.id;	
			end;
			end if;
		end;
	elsif o.status = 'FINISHED_SERVING' then
		begin
		select * into r from receipt where order_id = o.id;
		PERFORM updatestatusreceipt(r.id,'PENDING_DELIVERY', p_user);
		end;
	end if;
  return o;
end;

$BODY$;

ALTER FUNCTION public.updatestatuscustomerorder(numeric, character varying, numeric)
    OWNER TO postgres;

GRANT EXECUTE ON FUNCTION public.updatestatuscustomerorder(numeric, character varying, numeric) TO postgres;

GRANT EXECUTE ON FUNCTION public.updatestatuscustomerorder(numeric, character varying, numeric) TO PUBLIC;

GRANT EXECUTE ON FUNCTION public.updatestatuscustomerorder(numeric, character varying, numeric) TO auth_authenticated;



--07/11/2018
GRANT ALL ON SEQUENCE public.wash_bag_seq TO auth_authenticated;
GRANT ALL ON SEQUENCE public.wash_bag_detail_seq TO auth_authenticated;

-- FUNCTION: public.create_order_and_detail(customer_order, order_detail[])

-- DROP FUNCTION public.create_order_and_detail(customer_order, order_detail[]);

-- FUNCTION: public.create_wash_bag_for_receipt(numeric, numeric, numeric[], wash_bag_detail[])

-- DROP FUNCTION public.create_wash_bag_for_receipt(numeric, numeric, numeric[], wash_bag_detail[]);

CREATE OR REPLACE FUNCTION public.create_wash_bag_for_receipt(
	re_id numeric,
	curr_user numeric,
	wash_code numeric[],
	wb wash_bag_detail[])
    RETURNS receipt
    LANGUAGE 'plpgsql'

    COST 100
    VOLATILE 
AS $BODY$

declare
	rec receipt;
	new_id numeric;
	e wash_bag_detail;
	i numeric;
begin
	foreach i in array wash_code loop
	begin
		new_id = nextVal('wash_bag_seq');
		insert into wash_bag values (new_id, 'WB_'||new_id,curr_user,curr_user, now(), now(), 'ACTIVE', re_id);
		foreach e in array wb loop
		begin
			if e.wash_bag_id = i then
				insert into wash_bag_detail (wash_bag_id, service_type_id, unit_id, label_id, 
											 color_id, product_id, material_id, amount,create_by, update_by, status)
											 values (new_id, e.service_type_id, e.unit_id, e.label_id, e.color_id,
													e.product_id, e.material_id, e.amount, curr_user, curr_user, 'ACTIVE');
			end if;
		end;
		end loop;
	end;
	end loop;
	select * into rec from receipt where id = re_id;
	return rec;
end;

$BODY$;

ALTER FUNCTION public.create_wash_bag_for_receipt(numeric, numeric, numeric[], wash_bag_detail[])
    OWNER TO postgres;

GRANT EXECUTE ON FUNCTION public.create_wash_bag_for_receipt(numeric, numeric, numeric[], wash_bag_detail[]) TO postgres;

GRANT EXECUTE ON FUNCTION public.create_wash_bag_for_receipt(numeric, numeric, numeric[], wash_bag_detail[]) TO PUBLIC;

GRANT EXECUTE ON FUNCTION public.create_wash_bag_for_receipt(numeric, numeric, numeric[], wash_bag_detail[]) TO auth_authenticated WITH GRANT OPTION;



--
-- FUNCTION: public.create_order_and_detail(customer_order, order_detail[])

-- DROP FUNCTION public.create_order_and_detail(customer_order, order_detail[]);

CREATE OR REPLACE FUNCTION public.assign_To_Wash(
	re_id numeric,
	curr_user numeric,
	washer_id numeric)
    RETURNS receipt
    LANGUAGE 'plpgsql'
    COST 100
    VOLATILE 
AS $BODY$

declare
	wb_list wash_bag[];
	i wash_bag;
	r receipt;
begin
	select * into wb_list from wash_bag where receipt_id = re_id;
	foreach i in array wb_list loop
		insert into wash (wash_bag_id, washing_machine_id, create_by, update_by, status)
		values (i.id,washer_id,curr_user,curr_user,'PENDING_SERVING');
	end loop;
	select * into r from receipt where id = re_id;
	return r;
end;

$BODY$;

ALTER FUNCTION public.assign_To_Wash(
	re_id numeric,
	curr_user numeric,
	washer_id numeric)
    OWNER TO postgres;

GRANT EXECUTE ON FUNCTION public.assign_To_Wash(
	re_id numeric,
	curr_user numeric,
	washer_id numeric) TO postgres;

GRANT EXECUTE ON FUNCTION public.assign_To_Wash(
	re_id numeric,
	curr_user numeric,
	washer_id numeric) TO PUBLIC;

GRANT EXECUTE ON FUNCTION public.assign_To_Wash(
	re_id numeric,
	curr_user numeric,
	washer_id numeric) TO auth_authenticated WITH GRANT OPTION;

----------------------
GRANT ALL ON SEQUENCE public.wash_seq TO auth_authenticated;


-- FUNCTION: public.wash_search(numeric)

-- DROP FUNCTION public.wash_search(numeric);

CREATE OR REPLACE FUNCTION public.wash_search(
	br_id numeric)
    RETURNS SETOF wash_search 
    LANGUAGE 'sql'

    COST 100
    STABLE 
    ROWS 1000
AS $BODY$

    select co.id, re.id, wb.wash_bag_name, wm.washer_code, w.status  from wash w inner join wash_bag wb on wb.id = w.wash_bag_id
	inner join washing_machine wm on w.washing_machine_id = wm.id
	inner join receipt re on wb.receipt_id = re.id
	inner join customer_order co on re.order_id = co.id
	where w.status in ('PENDING_SERVING','SERVING') and co.branch_id = 2

$BODY$;

ALTER FUNCTION public.wash_search(numeric)
    OWNER TO postgres;

GRANT EXECUTE ON FUNCTION public.wash_search(numeric) TO postgres;

GRANT EXECUTE ON FUNCTION public.wash_search(numeric) TO PUBLIC;

GRANT EXECUTE ON FUNCTION public.wash_search(numeric) TO auth_authenticated;


-- FUNCTION: public.update_wash(numeric, character varying, numeric)

-- DROP FUNCTION public.update_wash(numeric, character varying, numeric);

-- FUNCTION: public.update_wash(numeric, character varying, numeric)

-- DROP FUNCTION public.update_wash(numeric, character varying, numeric);

CREATE OR REPLACE FUNCTION public.update_wash(
	co_id numeric,
	stt character varying,
	update_user numeric)
    RETURNS customer_order
    LANGUAGE 'plpgsql'

    COST 100
    VOLATILE 
AS $BODY$

declare
  co customer_order;
  re receipt;
  i numeric;
  wb_id numeric[];
begin
	select * into co from customer_order where id = co_id;
	select * into re from receipt where order_id = co.id;
	wb_id = ARRAY(select id from wash_bag where receipt_id  = re.id);
	foreach i in array wb_id loop
	begin
		update wash set (status,update_by, update_date) = (stt,update_user,now()) where wash_bag_id = i;
	end;
	end loop;
  return co;
end;

$BODY$;

ALTER FUNCTION public.update_wash(numeric, character varying, numeric)
    OWNER TO postgres;

GRANT EXECUTE ON FUNCTION public.update_wash(numeric, character varying, numeric) TO postgres;

GRANT EXECUTE ON FUNCTION public.update_wash(numeric, character varying, numeric) TO PUBLIC;

GRANT EXECUTE ON FUNCTION public.update_wash(numeric, character varying, numeric) TO auth_authenticated;









 -- FUNCTION: public.updatestatuscustomerorder(numeric, character varying, numeric)

-- DROP FUNCTION public.updatestatuscustomerorder(numeric, character varying, numeric);

CREATE OR REPLACE FUNCTION public.updatestatuscustomerorder(
	co_id numeric,
	p_status character varying,
	p_user numeric)
    RETURNS customer_order
    LANGUAGE 'plpgsql'

    COST 100
    VOLATILE 
AS $BODY$

declare
	o customer_order;
	receipt_id numeric;
	no_rec numeric;
	r receipt;
	co_status varchar;
	task_order task;
begin
	select status into co_status from customer_order co where co.id = co_id;
	update customer_order co set status = p_status where co.id = co_id;
	update customer_order co set update_date = now() where co.id = co_id;
	update order_detail od set status = p_status where od.order_id = co_id;
	update order_detail od set update_date = now() where od.order_id = co_id;
	select co.*  into o from customer_order co where co.id = co_id;
	select * into task_order from task where task_type='TASK_CUSTOMER_ORDER' and customer_order = o.id;
	update task set PREVIOUS_TASK = 'Y' where task_type='TASK_CUSTOMER_ORDER' and customer_order = o.id;
	insert into task (current_staff, previous_staff, task_type, customer_order, receipt, previous_status, current_status,PREVIOUS_TASK, branch_id)
		values (p_user, task_order.current_staff, 'TASK_CUSTOMER_ORDER', o.id, null, co_status, o.status, 'N', o.branch_id);
	if o.status = 'APPROVED' then
		begin
			receipt_id = nextval ('receipt_seq');
			insert into receipt (id, order_id, status, create_by, update_by)
			values (receipt_id,o.id, 'PENDING', p_user,p_user) returning * into r;
			insert into task (current_staff, previous_staff, task_type, customer_order, receipt, previous_status, current_status,PREVIOUS_TASK, branch_id)
			values (p_user, null, 'TASK_RECEIPT', null,receipt_id , null, r.status,'N',o.branch_id );
			select count(1) into no_rec from order_detail where order_id  = o.id;
			if no_rec> 0 then
			begin
				insert into receipt_detail (
					id, receipt_id, service_type_id, unit_id, label_id,
					color_id, product_id, material_id, amount,create_by, update_by, status,unit_price)
				select nextval('receipt_detail_seq'),receipt_id, service_type_id, unit_id, label_id,
					color_id, product_id, material_id, amount,p_user, p_user, 'PENDING', unit_price
				from order_detail where order_id  = o.id;	
			end;
			end if;
		end;
	elsif o.status = 'FINISHED_SERVING' then
		begin
		select * into r from receipt where order_id = o.id;
		PERFORM updatestatusreceipt(r.id,'PENDING_DELIVERY', p_user);
		end;
	end if;
	if o.status = 'PENDING_SERVING' or o.status = 'SERVING' or o.status = 'FINISHED_SERVING' then
		PERFORM update_wash (o.id,o.status, p_user );
	end if;
  return o;
end;

$BODY$;

ALTER FUNCTION public.updatestatuscustomerorder(numeric, character varying, numeric)
    OWNER TO postgres;

GRANT EXECUTE ON FUNCTION public.updatestatuscustomerorder(numeric, character varying, numeric) TO postgres;

GRANT EXECUTE ON FUNCTION public.updatestatuscustomerorder(numeric, character varying, numeric) TO PUBLIC;

GRANT EXECUTE ON FUNCTION public.updatestatuscustomerorder(numeric, character varying, numeric) TO auth_authenticated;


-- FUNCTION: public.getproductprice(unit_price)

-- DROP FUNCTION public.getproductprice(unit_price);

CREATE OR REPLACE FUNCTION public.getproductprice(
	unitprice unit_price)
    RETURNS unit_price
    LANGUAGE 'sql'

    COST 100
    STABLE 
AS $BODY$

    select *
	from unit_price
	where (product_id = unitPrice.product_id or unitPrice.product_id is null)
	and service_type_id = unitPrice.service_type_id 
	and unit_id = unitPrice.unit_id
	and apply_date = (select max(apply_date) from unit_price
	where (product_id = unitPrice.product_id or unitPrice.product_id is null)
	and service_type_id = unitPrice.service_type_id 
	and unit_id = unitPrice.unit_id
	and status = 'ACTIVE');
  
$BODY$;

ALTER FUNCTION public.getproductprice(unit_price)
    OWNER TO postgres;


-- FUNCTION: public.getlistproductprice(unit_price[])

-- DROP FUNCTION public.getlistproductprice(unit_price[]);

CREATE OR REPLACE FUNCTION public.getlistproductprice(
	unitprice unit_price[])
    RETURNS unit_price[]
    LANGUAGE 'plpgsql'

    COST 100
    VOLATILE 
AS $BODY$

declare
	res unit_price[];
	i unit_price;
	new_unit_price unit_price;
begin
	foreach i in array unitPrice loop
		select * into new_unit_price from getProductPrice (i);
		res = array_append(res,new_unit_price);								   
   end loop;
	return res;												 
end;
												
									   

$BODY$;

ALTER FUNCTION public.getlistproductprice(unit_price[])
    OWNER TO postgres;



--GRANT QUYỀN
REVOKE ALL ON TABLE public.wash_bag_detail FROM auth_authenticated;
GRANT DELETE ON TABLE public.wash_bag_detail TO auth_authenticated;

GRANT INSERT, SELECT, UPDATE, REFERENCES, TRIGGER ON TABLE public.wash_bag_detail TO auth_authenticated WITH GRANT OPTION;

REVOKE ALL ON TABLE public.wash_bag FROM auth_authenticated;
GRANT DELETE ON TABLE public.wash_bag TO auth_authenticated;

GRANT INSERT, SELECT, UPDATE, REFERENCES, TRIGGER ON TABLE public.wash_bag TO auth_authenticated WITH GRANT OPTION;

-- FUNCTION: public.assign_auto_to_wash(numeric, numeric)

-- DROP FUNCTION public.assign_auto_to_wash(numeric, numeric);

CREATE OR REPLACE FUNCTION public.assign_auto_to_wash(
	br_id numeric,
	curr_user numeric)
    RETURNS boolean
    LANGUAGE 'plpgsql'

    COST 100
    VOLATILE 
AS $BODY$

declare
	success boolean = false;
	re_id numeric[];
	service_type_list numeric[];
	color_group_list numeric[];
	new_wb_id numeric;
	i_re numeric;
	i_sv numeric;
	item_rd_sv numeric[];
	i_rd_sv numeric;
	item_rd_cl numeric[];
	i_rd_cl numeric;
	coun integer;
begin
	re_id = ARRAY(select re.id from receipt re inner join customer_order co on co.id = re.order_id where co.branch_id =  br_id and co.status = 'PENDING_SERVING');
	foreach i_re in array re_id loop
		begin
			select count(*) into coun from wash_bag where receipt_id = i_re;
			if coun = 0 then 
			begin
			service_type_list = ARRAY (select distinct service_type_id from receipt_detail where receipt_id = i_re);
			foreach i_sv in array service_type_list loop
				begin
					color_group_list = ARRAY(select distinct cg.id from receipt_detail rd 
											 inner join color cl on rd.color_id = cl.id
											 inner join color_group cg on cg.id = cl.color_group_id
											 where receipt_id = i_re and service_type_id = i_sv 
											 and rd.id in (select receipt_detail.id from receipt_detail where receipt_detail.receipt_id = i_re and receipt_detail.service_type_id = i_sv ));
					foreach i_rd_cl in array color_group_list loop
					begin
						new_wb_id = nextVal('wash_bag_seq');
						insert into wash_bag (id, wash_bag_name, create_by, update_by, status, receipt_id)
						values (new_wb_id, 'WB_'||new_wb_id, curr_user,curr_user, 'ACTIVE',i_re );
						
						insert into wash_bag_detail (wash_bag_id, service_type_id, unit_id, label_id, color_id, product_id,
													material_id, amount, create_by, update_by, status)
						select new_wb_id, i_sv, rd.unit_id, rd.label_id,rd.color_id, rd.product_id,rd.material_id,
						 rd.amount, curr_user, curr_user, 'ACTIVE' from receipt_detail rd
						 inner join color cl on rd.color_id = cl.id
						 inner join color_group cg on cg.id = cl.color_group_id
						 and cg.id = i_rd_cl
						 and rd.id in (select receipt_detail.id from receipt_detail where receipt_detail.receipt_id = i_re and receipt_detail.service_type_id = i_sv);
					end;
					end loop;
				 
				end;
			end loop;
		end; end if;
		end;
														  
	end loop;
	return success = true;
end;

$BODY$;

ALTER FUNCTION public.assign_auto_to_wash(numeric, numeric)
    OWNER TO postgres;

GRANT EXECUTE ON FUNCTION public.assign_auto_to_wash(numeric, numeric) TO postgres;

GRANT EXECUTE ON FUNCTION public.assign_auto_to_wash(numeric, numeric) TO PUBLIC;

GRANT EXECUTE ON FUNCTION public.assign_auto_to_wash(numeric, numeric) TO auth_authenticated WITH GRANT OPTION;


--09/11/2018

-- FUNCTION: public.get_info_washer(numeric)

-- DROP FUNCTION public.get_info_washer(numeric);

-- FUNCTION: public.get_info_washer(numeric)

-- DROP FUNCTION public.get_info_washer(numeric);

CREATE OR REPLACE FUNCTION public.get_info_washer(
	br_id numeric)
    RETURNS SETOF info_washer 
    LANGUAGE 'sql'

    COST 100
    STABLE 
    ROWS 1000
AS $BODY$

	select wa.id,
	(select count (*) from (select distinct re.id from receipt re inner join customer_order co on co.id = re.order_id
							inner join wash_bag wb on re.id = wb.receipt_id
							left join wash w on w.wash_bag_id = wb.id
							inner join washing_machine wm on wm.id = w.washing_machine_id
							where co.branch_id =  2 and co.status in  ('PENDING_SERVING','SERVING') and wm.id= wa.id ) sumcount ) as sumCount ,
	wa.washer_code,
	ARRAY(select distinct co.id from receipt re inner join customer_order co on co.id = re.order_id
							inner join wash_bag wb on re.id = wb.receipt_id
							left join wash w on w.wash_bag_id = wb.id
							inner join washing_machine wm on wm.id = w.washing_machine_id
							where co.branch_id =  2 and co.status in  ('SERVING') and wm.id= wa.id ) as serving,
	ARRAY(select distinct co.id from receipt re inner join customer_order co on co.id = re.order_id
							inner join wash_bag wb on re.id = wb.receipt_id
							left join wash w on w.wash_bag_id = wb.id
							inner join washing_machine wm on wm.id = w.washing_machine_id
							where co.branch_id =  2 and co.status in  ('PENDING_SERVING') and wm.id= wa.id ) as pending
	 from washing_machine wa where  wa.branch_id = br_id;

$BODY$;

ALTER FUNCTION public.get_info_washer(numeric)
    OWNER TO postgres;



--10/11/2018

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
	select count(*) into coun from wash where wash_bag_id in (select id from wash_bag where receipt_id = re_id) and status <> 'PENDING_SERVING';
	select max(sn) into sn_max from wash where washing_machine_id = washer_id and status = 'PENDING_SERVING';
	if sn_max is null then
		sn_max = 0;
	end if;
	if coun = 0 then
	delete from wash where wash_bag_id in (select id from wash_bag where receipt_id = re_id) and status = 'PENDING_SERVING';
	foreach i in array wb_list loop
		insert into wash (wash_bag_id, washing_machine_id, create_by, update_by, status,sn)
		values (i,washer_id,curr_user,curr_user,'PENDING_SERVING',sn_max + 1);
	end loop;
	select * into r from receipt where id = re_id;
	return r;
	end if;
	return null;
end;

$BODY$;

ALTER FUNCTION public.assign_to_wash(numeric, numeric, numeric)
    OWNER TO postgres;

GRANT EXECUTE ON FUNCTION public.assign_to_wash(numeric, numeric, numeric) TO postgres;

GRANT EXECUTE ON FUNCTION public.assign_to_wash(numeric, numeric, numeric) TO PUBLIC;

GRANT EXECUTE ON FUNCTION public.assign_to_wash(numeric, numeric, numeric) TO auth_authenticated WITH GRANT OPTION;



-- FUNCTION: public.wash_search(numeric)

-- DROP FUNCTION public.wash_search(numeric);

CREATE OR REPLACE FUNCTION public.wash_search(
	br_id numeric)
    RETURNS SETOF wash_search 
    LANGUAGE 'sql'

    COST 100
    STABLE 
    ROWS 1000
AS $BODY$

    select co.id , re.id, wb.wash_bag_name, wm.washer_code, w.status,cu.full_name,w.sn  from wash w inner join wash_bag wb on wb.id = w.wash_bag_id
	inner join washing_machine wm on w.washing_machine_id = wm.id
	inner join receipt re on wb.receipt_id = re.id
	inner join customer_order co on re.order_id = co.id
	inner join customer cu on cu.id = co.customer_id
	where w.status in ('PENDING_SERVING','SERVING') and co.branch_id = br_id

$BODY$;

ALTER FUNCTION public.wash_search(numeric)
    OWNER TO postgres;

GRANT EXECUTE ON FUNCTION public.wash_search(numeric) TO postgres;

GRANT EXECUTE ON FUNCTION public.wash_search(numeric) TO PUBLIC;

GRANT EXECUTE ON FUNCTION public.wash_search(numeric) TO auth_authenticated;


--11/11/2018

-- FUNCTION: public.get_info_washer(numeric)

-- DROP FUNCTION public.get_info_washer(numeric);

CREATE OR REPLACE FUNCTION public.get_info_washer(
	br_id numeric)
    RETURNS SETOF info_washer 
    LANGUAGE 'sql'

    COST 100
    STABLE 
    ROWS 1000
AS $BODY$

	select wa.id,
	(select count (*) from (select distinct re.id from receipt re inner join customer_order co on co.id = re.order_id
							inner join wash_bag wb on re.id = wb.receipt_id
							left join wash w on w.wash_bag_id = wb.id
							inner join washing_machine wm on wm.id = w.washing_machine_id
							where co.branch_id =  2 and co.status in  ('PENDING_SERVING','SERVING') and wm.id= wa.id ) sumcount ) as sumCount ,
	wa.washer_code,
	ARRAY(select distinct co.id from receipt re inner join customer_order co on co.id = re.order_id
							inner join wash_bag wb on re.id = wb.receipt_id
							left join wash w on w.wash_bag_id = wb.id
							inner join washing_machine wm on wm.id = w.washing_machine_id
							where co.branch_id =  2 and co.status in  ('SERVING') and wm.id= wa.id ) as serving,
	ARRAY(select distinct co.id from receipt re inner join customer_order co on co.id = re.order_id
							inner join wash_bag wb on re.id = wb.receipt_id
							left join wash w on w.wash_bag_id = wb.id
							inner join washing_machine wm on wm.id = w.washing_machine_id
							where co.branch_id =  2 and co.status in  ('PENDING_SERVING') and wm.id= wa.id ) as pending
	 from washing_machine wa where  wa.branch_id = br_id and wa.status = 'ACTIVE';

$BODY$;

ALTER FUNCTION public.get_info_washer(numeric)
    OWNER TO postgres;

-- FUNCTION: public.assign_type_one_to_wash()

-- DROP FUNCTION public.assign_type_one_to_wash(assign_work[]);

CREATE OR REPLACE FUNCTION public.assign_type_one_to_wash(
	list assign_work[])
    RETURNS boolean
    LANGUAGE 'plpgsql'

    COST 100
    VOLATILE 
AS $BODY$

declare
	i assign_work;
	success boolean = false;
begin
	foreach i in array list loop
	begin
		perform assign_to_wash (i.re_id, i.curr_user,i.washer_id);
		success = true;
	end;
	end loop;
	return success;
end;

$BODY$;

ALTER FUNCTION public.assign_type_one_to_wash(
	list assign_work[])
    OWNER TO postgres;

GRANT EXECUTE ON FUNCTION public.assign_type_one_to_wash(
	list assign_work[]) TO postgres;

GRANT EXECUTE ON FUNCTION public.assign_type_one_to_wash(
	list assign_work[]) TO PUBLIC;

GRANT EXECUTE ON FUNCTION public.assign_type_one_to_wash(
	list assign_work[]) TO auth_authenticated WITH GRANT OPTION;

