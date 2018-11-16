
-- FUNCTION: public.getprepareorderserving(numeric)

-- DROP FUNCTION public.getprepareorderserving(numeric);

CREATE OR REPLACE FUNCTION public.getprepareorderserving(
	br_id numeric)
    RETURNS SETOF receipt 
    LANGUAGE 'sql'

    COST 100
    STABLE 
    ROWS 1000
AS $BODY$


    select r.* from receipt r 
    left join receipt_detail rd on r.id = rd.receipt_id 
    inner join customer_order co on co.id  = r.order_id 
    where co.status = 'PENDING_SERVING' 
    and r.status = 'RECEIVED'
    and co.branch_id = br_id;


$BODY$;

ALTER FUNCTION public.getprepareorderserving(numeric)
    OWNER TO postgres;

