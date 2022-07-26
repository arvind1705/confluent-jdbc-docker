# confluent-jdbc-docker

# Steps to bring up a Confluent Stack in Docker
1. ```docker-compose up```
2. Wait till entire stack is up and running
3. Visit the Confluent Control Center at ```http://localhost:9021/```

# Steps to test Confluent JDBC
1. Create these topics in control center:
    - topic: `customers`
    - topic: `customers-dlq`
    - topic: `customers-jsonsr` 

2. Create below streams in KSQLDB:

    ```CREATE STREAM customer_raw (id int, first_name varchar, last_name varchar, email varchar, gender varchar comments varchar) WITH (KAFKA_TOPIC='customers', VALUE_FORMAT='json');```

    ```CREATE STREAM customer_jsonsr WITH (KAFKA_TOPIC='customers-jsonsr', VALUE_FORMAT='JSON_SR') AS SELECT id,  first_name, last_name, email, gender, comments from customer_raw emit changes;```

    Stream to read DLQ headers
    
    ```CREATE STREAM dlq_headers (headers ARRAY<STRUCT<key STRING, value BYTES>> HEADERS) WITH (KAFKA_TOPIC='customers-dlq', VALUE_FORMAT='json');```

3. Insert below data into Kafka topic: `customers`

      ```
      {
          "id": 1,
          "first_name": "Aravind",
          "last_name": "G",
          "email": "g@arvind1705.com",
          "gender": "Male",
          "comments": "Hellow World"
      }
      ```
(Update Id's and other values insert more data as needed.)

4. Setup JDBC Connector in Kafka Connect in control center:

```
{
  "name": "JdbcSinkConnectorConnector_0",
  "config": {
    "connector.class": "io.confluent.connect.jdbc.JdbcSinkConnector",
    "key.converter": "org.apache.kafka.connect.storage.StringConverter",
    "value.converter": "io.confluent.connect.json.JsonSchemaConverter",
    "errors.tolerance": "all",
    "errors.log.enable": "true",
    "errors.log.include.messages": "true",
    "topics": "customers-jsonsr",
    "errors.deadletterqueue.topic.name": "customers-dlq",
    "errors.deadletterqueue.context.headers.enable": "true",
    "connection.url": "jdbc:postgresql://postgres:5432/postgres",
    "connection.user": "connect_user",
    "connection.password": "asgard",
    "dialect.name": "PostgreSqlDatabaseDialect",
    "table.name.format": "test.customers",
    "auto.create": "false",
    "auto.evolve": "false",
    "quote.sql.identifiers": "never",
    "key.converter.schemas.enable": "false",
    "value.converter.schema.registry.url": "http://schema-registry:8081",
    "value.converter.schemas.enable": "false"
  }
}

```
Visit the connect url to check status 
```http://localhost:8083/connectors/JdbcSinkConnectorConnector_0/status/```



# Steps to check data in database:

1. Run below command in Postgresql:

    ``` docker-compose exec postgres bash -c 'psql -U $POSTGRES_USER $POSTGRES_DB' ```
    
    ``` "SELECT * FROM test.customers" ```
    
2. Use same psql terminal to run other database commands. 
3. Check setup.sql file in postgres folder to run db commands while starting Confluent stack.


# Steps to simualate error in Kafka Connect to check DLQ headers:

1. Execute below stream. It'll fail to insert data into db as pincode column is not present in DB 

```CREATE STREAM customer_jsonsr WITH (KAFKA_TOPIC='customers-jsonsr', VALUE_FORMAT='JSON_SR') AS SELECT id,  first_name, last_name, email, gender, comments, "560010" as pincode from customer_raw emit changes;```

2. Read DLQ header data in dlq stream:

```
select FROM_BYTES(HEADERS[1]-> value, 'ascii') as source_topic, FROM_BYTES(HEADERS[2]-> value, 'ascii') as partition_num, FROM_BYTES(HEADERS[3]-> value, 'ascii') as partition_offset, FROM_BYTES(HEADERS[4]-> value, 'ascii') as connector_name, FROM_BYTES(HEADERS[5]-> value, 'ascii') as errors_stage, FROM_BYTES(HEADERS[6]-> value, 'ascii') as class_name, FROM_BYTES(HEADERS[7]-> value, 'ascii') as exception_class_name,FROM_BYTES(HEADERS[8]-> value, 'ascii') as exception_message, FROM_BYTES(HEADERS[9]-> value, 'ascii') as exception_stacktrace from DLQ_HEADERS emit changes;

```
