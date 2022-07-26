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


