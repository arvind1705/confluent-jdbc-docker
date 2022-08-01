CREATE USER connect_user WITH PASSWORD 'asgard';
GRANT ALL PRIVILEGES ON DATABASE postgres TO connect_user;

CREATE SCHEMA test AUTHORIZATION connect_user;

CREATE SCHEMA security AUTHORIZATION connect_user;

-- Courtesy of https://techblog.covermymeds.com/databases/on-update-timestamps-mysql-vs-postgres/
CREATE FUNCTION public.update_updated_at_column() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
  BEGIN
    NEW.update_ts = NOW();
    RETURN NEW;
  END;
$$;


create table test.customers (
	ID INT PRIMARY KEY,
	FIRST_NAME VARCHAR(50),
	LAST_NAME VARCHAR(50),
	EMAIL VARCHAR(50),
	GENDER VARCHAR(50),
	COMMENTS VARCHAR(90),
	UPDATE_TS TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TRIGGER customers_updated_at_modtime BEFORE UPDATE ON test.customers FOR EACH ROW EXECUTE PROCEDURE update_updated_at_column();

GRANT SELECT ON test.customers TO connect_user;
GRANT INSERT ON test.customers TO connect_user;


insert into test.customers (ID, FIRST_NAME, LAST_NAME, EMAIL, GENDER, COMMENTS) values (1, 'Bibby', 'Argabrite', 'bargabrite0@google.com.hk', 'Female', 'Reactive exuding productivity');


CREATE TABLE test.EMPLOYEES (
	id SERIAL PRIMARY KEY, 
	first_name VARCHAR(50), 
	last_name VARCHAR(50), 
	email VARCHAR(50), 
	mobile_no BIGINT, 
	date_of_birth DATE,
	UPDATE_TS TIMESTAMP DEFAULT CURRENT_TIMESTAMP
	);

CREATE FUNCTION get_random_string() RETURNS TEXT LANGUAGE SQL AS $$ 
SELECT STRING_AGG ( SUBSTR ( 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ', CEIL (RANDOM() * 52)::integer, 1), '') 
FROM GENERATE_SERIES(1, 10) 
$$;

GRANT SELECT ON test.EMPLOYEES TO connect_user;
GRANT INSERT ON test.EMPLOYEES TO connect_user;

CREATE FUNCTION insert_record() RETURNS VOID LANGUAGE PLPGSQL AS $$
DECLARE first_name TEXT= INITCAP(get_random_string());
DECLARE last_name TEXT= INITCAP(get_random_string());
DECLARE email TEXT= LOWER(CONCAT(first_name, '.', last_name, '@gmail.com'));
DECLARE mobile_no BIGINT=CAST(1000000000 + FLOOR(RANDOM() * 9000000000) AS BIGINT);
DECLARE date_of_birth DATE= CAST( NOW() - INTERVAL '100 year' * RANDOM() AS DATE);
BEGIN
INSERT INTO test.EMPLOYEES (first_name, last_name, email, mobile_no, date_of_birth) VALUES (first_name, last_name, email, mobile_no, date_of_birth);
END;
$$;

SELECT insert_record() FROM GENERATE_SERIES(1, 10);