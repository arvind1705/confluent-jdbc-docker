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

    ```
    CREATE STREAM customer_raw (id int, first_name varchar, last_name varchar, email varchar, gender varchar, comments varchar) WITH             (KAFKA_TOPIC='customers', VALUE_FORMAT='json');

    CREATE STREAM customer_jsonsr WITH (KAFKA_TOPIC='customers-jsonsr', VALUE_FORMAT='JSON_SR') AS SELECT id,  first_name, last_name, email, gender, comments from customer_raw emit changes;
    ```

    Stream to read DLQ headers
    
    ```
    CREATE STREAM DLQ_HEADERS (HEADERS ARRAY<STRUCT<KEY STRING, VALUE BYTES>> HEADERS) WITH (KAFKA_TOPIC='CUSTOMERS-DLQ', VALUE_FORMAT='JSON');
    ```

3. Insert below data into Kafka topic: `customers`

      ```
      {
          "id": 1,
          "first_name": "Aravind",
          "last_name": "G",
          "email": "g.aravind@test.com",
          "gender": "Male",
          "comments": "Hello World"
      }
      ```
(Update Ids and other values insert more data as needed.)

4. Upload sample_sink_connector.json (file in repo) connnector config in Kafka Connect page in control center. 

Execute curl command to check connector status

```curl http://127.0.0.1:8083/connectors/sample_sink_connector/status```


# Steps to check data in database:

1. Run below command in different bash terminal to view data in database:

    ``` docker-compose exec postgres bash -c 'psql -U $POSTGRES_USER $POSTGRES_DB' ```
    
    ``` "SELECT * FROM test.customers;" ```
    
2. Use same psql terminal to run other database commands. 
3. Check setup.sql file in postgres folder to run db commands while starting Confluent stack.


# Steps to simulate error in Kafka Connect and insert data into DLQ:

1. Insert below sample data directly into Kafka topic: `customers-jsonsr`. 

Data won't be inserted into database because of serialization error and data will be inserted into DLQ topic.

```
      {
          "id": 1,
          "first_name": "Aravind",
          "last_name": "G",
          "email": "g.aravind@test.com",
          "gender": "Male",
          "comments": "Hello World"
      }
```

2. Read DLQ header data in dlq stream:

```
select FROM_BYTES(HEADERS[1]-> value, 'ascii') as source_topic, FROM_BYTES(HEADERS[2]-> value, 'ascii') as partition_num, FROM_BYTES(HEADERS[3]-> value, 'ascii') as partition_offset, FROM_BYTES(HEADERS[4]-> value, 'ascii') as connector_name, FROM_BYTES(HEADERS[5]-> value, 'ascii') as errors_stage, FROM_BYTES(HEADERS[6]-> value, 'ascii') as class_name, FROM_BYTES(HEADERS[7]-> value, 'ascii') as exception_class_name,FROM_BYTES(HEADERS[8]-> value, 'ascii') as exception_message, FROM_BYTES(HEADERS[9]-> value, 'ascii') as exception_stacktrace from DLQ_HEADERS emit changes;
```


# Query to test source connector:

```
select count(*) from test.employees;

truncate TABLE test.employees restart identity;

SELECT insert_record() FROM GENERATE_SERIES(1, 10);

select * from test.employees;
```
