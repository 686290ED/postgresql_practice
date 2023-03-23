--reference https://stackoverflow.com/questions/58258681/postgresql-complex-logic-function-plpgsql

CREATE TABLE products(pro_id SERIAL PRIMARY KEY,name varchar(64));
CREATE TABLE bill( bill_id SERIAL PRIMARY KEY, name varchar(64), approved boolean DEFAULT false);
CREATE TABLE inventory(inv_id SERIAL PRIMARY KEY, pro_id integer REFERENCES products(pro_id),quantity NUMERIC(12,2));
CREATE TABLE bill_products( 
bill_id int REFERENCES bill(bill_id) NOT NULL, 
pro_id int REFERENCES products(pro_id) NOT NULL,
quantity NUMERIC(12,2) NOT NULL,
delivered NUMERIC(12,2) NOT NULL,
CONSTRAINT test CHECK( delivered <= quantity )
);

INSERT INTO products(name) VALUES('Product 1');
INSERT INTO products(name) VALUES('Product 2');
INSERT INTO bill(name) VALUES('List 1');
INSERT INTO bill_products(bill_id, pro_id, quantity, delivered)
VALUES(1,1,500.00,0.00);
INSERT INTO bill_products(bill_id, pro_id, quantity, delivered)
VALUES(1,2,10000.00,0.00);

create table delivery(
deli_id serial primary key,
info jsonb);
INSERT INTO delivery(info)
VALUES('[ 
      {
        "bill_id" : 1,
        "product_id" : 1,
        "delivered": 100
      },
      {
        "bill_id" : 1,
        "product_id" : 2,
        "delivered": 400
      } 
 ]'),
 ('[ 
      {
        "bill_id" : 1,
        "product_id" : 1,
        "delivered": 400
      },
      {
        "bill_id" : 1,
        "product_id" : 2,
        "delivered": 400
      } 
 ]');
 
CREATE OR REPLACE FUNCTION update_inventory(delivery jsonb)
RETURNS text
AS $$
DECLARE
  deli jsonb;
  res text := '';
  updated bill_products;
BEGIN 
res := (jsonb_array_length(delivery))::text;
FOR deli IN SELECT jsonb_array_elements(delivery)
LOOP 
  RAISE INFO 'bill % product % delivered %', deli->>'bill_id', deli->>'product_id', deli->>'delivered';
  UPDATE bill_products 
    SET delivered = delivered + (deli->>'delivered')::numeric
    WHERE bill_id = (deli->>'bill_id')::int
    AND pro_id = (deli->>'product_id')::int
    RETURNING * INTO STRICT updated;
  INSERT INTO inventory(pro_id, quantity) 
    VALUES(updated.pro_id, updated.delivered);
  IF updated.delivered = updated.quantity
    THEN UPDATE bill SET approved = 'true'
  	WHERE bill_id = updated.bill_id;
  END IF;
END LOOP; 
RETURN res;
END;
$$language plpgsql;

BEGIN;
select update_inventory(info) from delivery;
select * from bill;
ROLLBACK;