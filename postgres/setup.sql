CREATE USER connect_user WITH PASSWORD 'asgard';
GRANT ALL PRIVILEGES ON DATABASE postgres TO connect_user;

CREATE SCHEMA demo AUTHORIZATION connect_user;

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


create table demo.customers (
	id INT PRIMARY KEY,
	first_name VARCHAR(50),
	last_name VARCHAR(50),
	email VARCHAR(50),
	gender VARCHAR(50),
	comments VARCHAR(90),
	UPDATE_TS TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TRIGGER customers_updated_at_modtime BEFORE UPDATE ON demo.customers FOR EACH ROW EXECUTE PROCEDURE update_updated_at_column();

GRANT SELECT ON demo.customers TO connect_user;

insert into demo.customers (id, first_name, last_name, email, gender, comments) values (1, 'Bibby', 'Argabrite', 'bargabrite0@google.com.hk', 'Female', 'Reactive exuding productivity');
insert into demo.customers (id, first_name, last_name, email, gender, comments) values (2, 'Auberon', 'Sulland', 'asulland1@slideshare.net', 'Male', 'Organized context-sensitive Graphical User Interface');
insert into demo.customers (id, first_name, last_name, email, gender, comments) values (3, 'Marv', 'Dalrymple', 'mdalrymple2@macromedia.com', 'Male', 'Versatile didactic pricing structure');
insert into demo.customers (id, first_name, last_name, email, gender, comments) values (4, 'Nolana', 'Yeeles', 'nyeeles3@drupal.org', 'Female', 'Adaptive real-time archive');
insert into demo.customers (id, first_name, last_name, email, gender, comments) values (5, 'Modestia', 'Coltart', 'mcoltart4@scribd.com', 'Female', 'Reverse-engineered non-volatile success');


