
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
  insert into customer_order values (o.*) returning * into o;
  foreach i in array d loop
    i.id = nextval('order_detail_seq');
    i.order_id = o.id;
	i.create_date = now();
  	i.update_date = now();
    insert into order_detail values (i.*);
  end loop;
  return o;
end;
$$ language plpgsql volatile;

GRANT EXECUTE ON FUNCTION create_order_and_detail(o customer_order, d order_detail[]) TO auth_authenticated; 
GRANT ALL ON SEQUENCE public.customer_order_seq TO auth_authenticated;
GRANT ALL ON SEQUENCE public.order_detail_seq TO auth_authenticated;

--get amount money order
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