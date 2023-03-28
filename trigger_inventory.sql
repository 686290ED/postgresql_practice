CREATE OR REPLACE FUNCTION reverse_inventory(delivery jsonb)
RETURNS void
AS $$
DECLARE
  deli jsonb;
  res text := '';
  deleted bill_products;
BEGIN 
  res := (jsonb_array_length(delivery))::text;
  --RAISE INFO 'reversed delivery has % batches', res;
  FOR deli IN SELECT jsonb_array_elements(delivery)
  LOOP 
    --RAISE INFO 'bill % product % delivered %', deli->>'bill_id', deli->>'product_id', deli->>'delivered';
    UPDATE bill_products 
      SET delivered = delivered - (deli->>'delivered')::numeric
      WHERE bill_id = (deli->>'bill_id')::int
      AND pro_id = (deli->>'product_id')::int
      RETURNING * INTO STRICT deleted;
    DELETE FROM inventory
      WHERE pro_id = deleted.pro_id AND quantity = deleted.delivered;
  END LOOP; 
UPDATE bill
  SET approved = NOT EXISTS (SELECT 1
                             FROM bill_products
                             WHERE bill_products.bill_id = bill.bill_id
                             AND delivered < quantity)
      WHERE bill_id IN (SELECT DISTINCT (d->>'bill_id')::int
                        FROM jsonb_array_elements(delivery) d);
RETURN;
END;
$$language plpgsql;
COMMENT ON FUNCTION reverse_inventory(jsonb) IS 'Reverse the inventory record on table bill_products/bill/inventory';

CREATE OR REPLACE FUNCTION delivery_change() RETURNS trigger AS $change$
DECLARE
  cnt int;
  deli jsonb;
  updated jsonb;
  BEGIN
	IF (TG_OP = 'INSERT') THEN
	  cnt := (SELECT COUNT(*) FROM new_table);
	  RAISE INFO '% delivery came.', cnt;
	  FOR deli in SELECT info FROM new_table LOOP
	    PERFORM update_inventory(deli);
	  END LOOP;
	ELSIF (TG_OP = 'DELETE') THEN
	  cnt := (SELECT COUNT(*) FROM old_table);
	  RAISE INFO '!!!% delivery is deleted, please recheck!!!', cnt;	
	  FOR deli in SELECT info FROM old_table LOOP
	    PERFORM reverse_inventory(deli);
	  END LOOP;
	ELSIF (TG_OP = 'UPDATE') THEN
      updated:= (SELECT json_agg(row_to_json(r)) AS updated_value
		  FROM 
		  (SELECT new_records.deli_id, bill_id, product_id, (new_records.delivered - old_records.delivered) AS delivered
		   FROM 
		  (SELECT deli_id, bill_id, product_id, delivered 
		  FROM new_table, 
		  jsonb_to_recordset(new_table.info) AS specs(bill_id int, delivered int, product_id int)) new_records
		  JOIN (
		  SELECT deli_id, bill_id, product_id, delivered 
		  FROM old_table, 
		  jsonb_to_recordset(old_table.info) AS specs(bill_id int, delivered int, product_id int)) old_records
		  USING(deli_id, bill_id, product_id)
		  WHERE new_records.delivered <> old_records.delivered) r);
	  IF updated IS NOT null
		THEN 
		  cnt := (SELECT COUNT(*) FROM old_table);
		  RAISE INFO '!!!% delivery is updated, please recheck!!!', cnt;	
	      PERFORM update_inventory(updated);
		END IF;
	END IF;
	RETURN NULL;
  END;
$change$ LANGUAGE plpgsql;
COMMENT ON FUNCTION delivery_change IS 'Trigger definition for changes in delivery table';

DROP TRIGGER IF EXISTS delivery_insert_trg ON delivery;
CREATE TRIGGER delivery_insert_trg
  AFTER INSERT ON delivery
  REFERENCING NEW TABLE AS new_table
  FOR EACH STATEMENT EXECUTE FUNCTION delivery_change();	
DROP TRIGGER IF EXISTS delivery_reverse_trg ON delivery;
CREATE TRIGGER delivery_reverse_trg
  AFTER DELETE ON delivery
  REFERENCING OLD TABLE AS old_table
  FOR EACH STATEMENT EXECUTE FUNCTION delivery_change();
DROP TRIGGER IF EXISTS delivery_update_trg ON delivery;
CREATE TRIGGER delivery_update_trg
  AFTER UPDATE ON delivery
  REFERENCING NEW TABLE AS new_table OLD TABLE AS old_table
  FOR EACH STATEMENT EXECUTE FUNCTION delivery_change(); 

UPDATE delivery SET info = jsonb_set(info, '{1, delivered}', '200') WHERE deli_id = 3;  