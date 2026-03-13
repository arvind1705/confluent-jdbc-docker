# confluent-jdbc-docker

Local Confluent Platform stack (v7.6.10) with Kafka, ksqlDB, Schema Registry, Kafka Connect (JDBC), and PostgreSQL — all in Docker.

## Stack

| Service | Image | Port |
|---|---|---|
| Zookeeper | `confluentinc/cp-zookeeper:7.6.10` | 2181 |
| Broker | `confluentinc/cp-server:7.6.10` | 9092 |
| Schema Registry | `confluentinc/cp-schema-registry:7.6.10` | 8081 |
| Kafka Connect | `cnfldemos/cp-server-connect-datagen:0.6.4-7.6.0` | 8083 |
| ksqlDB Server | `confluentinc/cp-ksqldb-server:7.6.10` | 8088 |
| ksqlDB CLI | `confluentinc/cp-ksqldb-cli:7.6.10` | — |
| Control Center | `confluentinc/cp-enterprise-control-center:7.6.10` | 9021 |
| REST Proxy | `confluentinc/cp-kafka-rest:7.6.10` | 8082 |
| PostgreSQL | `postgres` (latest) | 5432 |
| kcat | `edenhill/kcat:1.7.1` | — |

---

## 1. Start the Stack

```bash
docker-compose up -d
```

Wait ~60 seconds for all services to initialize, then verify:

```bash
# Check all containers are up
docker-compose ps

# Verify Kafka Connect is ready and JDBC plugin is loaded
curl -s http://localhost:8083/connector-plugins | grep JdbcSinkConnector

# Verify ksqlDB is running
curl -s http://localhost:8088/info
```

Control Center UI: http://localhost:9021

---

## 2. Create Kafka Topics

```bash
docker-compose exec broker kafka-topics --bootstrap-server broker:29092 --create --topic customers --partitions 1 --replication-factor 1

docker-compose exec broker kafka-topics --bootstrap-server broker:29092 --create --topic customers-dlq --partitions 1 --replication-factor 1

docker-compose exec broker kafka-topics --bootstrap-server broker:29092 --create --topic customers-jsonsr --partitions 1 --replication-factor 1

docker-compose exec broker kafka-topics --bootstrap-server broker:29092 --create --topic employees --partitions 1 --replication-factor 1

# Verify
docker-compose exec broker kafka-topics --bootstrap-server broker:29092 --list
```

---

## 3. Create ksqlDB Streams

```bash
# Open the ksqlDB CLI
docker-compose exec ksqldb-cli ksql http://ksqldb-server:8088
```

Or use the REST API directly:

**Stream 1 — Raw customers stream (reads from `customers` topic):**

```bash
curl -s -X POST http://localhost:8088/ksql \
  -H "Content-Type: application/vnd.ksql.v1+json; charset=utf-8" \
  -d '{
    "ksql": "CREATE OR REPLACE STREAM CUSTOMER_RAW (ID INTEGER, NAME STRUCT<FIRST_NAME STRING, LAST_NAME STRING>, EMAIL STRING, GENDER STRING, COMMENTS STRING) WITH (KAFKA_TOPIC='\''customers'\'', KEY_FORMAT='\''KAFKA'\'', VALUE_FORMAT='\''JSON'\'');",
    "streamsProperties": {"ksql.streams.auto.offset.reset": "earliest"}
  }'
```

**Stream 2 — Flattened stream in JSON_SR format (feeds into sink connector):**

```bash
curl -s -X POST http://localhost:8088/ksql \
  -H "Content-Type: application/vnd.ksql.v1+json; charset=utf-8" \
  -d '{
    "ksql": "CREATE OR REPLACE STREAM customer_jsonsr WITH (KAFKA_TOPIC='\''customers-jsonsr'\'', VALUE_FORMAT='\''JSON_SR'\'') AS SELECT id, name->first_name as first_name, name->last_name as last_name, email, gender, comments FROM customer_raw EMIT CHANGES;",
    "streamsProperties": {"ksql.streams.auto.offset.reset": "earliest"}
  }'
```

**Stream 3 — DLQ headers stream (for inspecting dead-letter queue):**

```bash
curl -s -X POST http://localhost:8088/ksql \
  -H "Content-Type: application/vnd.ksql.v1+json; charset=utf-8" \
  -d '{
    "ksql": "CREATE STREAM DLQ_HEADERS (HEADERS ARRAY<STRUCT<KEY STRING, VALUE BYTES>> HEADERS) WITH (KAFKA_TOPIC='\''customers-dlq'\'', VALUE_FORMAT='\''JSON'\'');",
    "streamsProperties": {"ksql.streams.auto.offset.reset": "earliest"}
  }'
```

List all streams to verify:

```bash
curl -s -X POST http://localhost:8088/ksql \
  -H "Content-Type: application/vnd.ksql.v1+json; charset=utf-8" \
  -d '{"ksql": "SHOW STREAMS;"}'
```

---

## 4. Insert Data into Kafka

```bash
echo '{"id":2,"name":{"first_name":"Aravind","last_name":"G"},"email":"g.aravind@test.com","gender":"Male","comments":"Hello World"}' | \
  docker-compose exec -T broker kafka-console-producer \
    --bootstrap-server broker:29092 \
    --topic customers
```

> Increment `id` and change values to insert more records.

---

## 5. Deploy the Sink Connector (Kafka → PostgreSQL)

Uploads `sink_connector.json` to Kafka Connect — writes `customers-jsonsr` topic data into `test.customers` table in PostgreSQL.

```bash
curl -s -X POST http://localhost:8083/connectors \
  -H "Content-Type: application/json" \
  -d @sink_connector.json
```

Check connector status:

```bash
curl -s http://127.0.0.1:8083/connectors/sample_sink_connector/status
```

Expected output:
```json
{
  "name": "sample_sink_connector",
  "connector": { "state": "RUNNING", "worker_id": "connect:8083" },
  "tasks": [{ "id": 0, "state": "RUNNING", "worker_id": "connect:8083" }],
  "type": "sink"
}
```

---

## 6. Verify Data in PostgreSQL

```bash
docker-compose exec postgres bash -c 'psql -U $POSTGRES_USER $POSTGRES_DB -c "SELECT * FROM test.customers;"'
```

Use the same `psql` session for further queries:

```bash
docker-compose exec postgres bash -c 'psql -U $POSTGRES_USER $POSTGRES_DB'
```

> The `test.customers` table and schema are created by `postgres/setup.sql` on first startup.

---

## 7. Simulate a DLQ Error

Insert malformed data directly into `customers-jsonsr` (bypasses the schema, causes a deserialization error in the sink connector — record lands in `customers-dlq`):

```bash
echo '{"id":99,"first_name":"Bad","last_name":"Record","email":"bad@test.com","gender":"Unknown","comments":"This will fail"}' | \
  docker-compose exec -T broker kafka-console-producer \
    --bootstrap-server broker:29092 \
    --topic customers-jsonsr
```

Read DLQ header data in ksqlDB to inspect the error:

```bash
curl -s -X POST http://localhost:8088/query \
  -H "Content-Type: application/vnd.ksql.v1+json; charset=utf-8" \
  -d '{
    "ksql": "SELECT FROM_BYTES(HEADERS[1]->value, '\''ascii'\'') as source_topic, FROM_BYTES(HEADERS[2]->value, '\''ascii'\'') as partition_num, FROM_BYTES(HEADERS[3]->value, '\''ascii'\'') as partition_offset, FROM_BYTES(HEADERS[4]->value, '\''ascii'\'') as connector_name, FROM_BYTES(HEADERS[5]->value, '\''ascii'\'') as errors_stage, FROM_BYTES(HEADERS[6]->value, '\''ascii'\'') as class_name, FROM_BYTES(HEADERS[7]->value, '\''ascii'\'') as exception_class_name, FROM_BYTES(HEADERS[8]->value, '\''ascii'\'') as exception_message FROM DLQ_HEADERS EMIT CHANGES LIMIT 1;",
    "streamsProperties": {"ksql.streams.auto.offset.reset": "earliest"}
  }'
```

---

## 8. Source Connector (PostgreSQL → Kafka)

Uploads `source_connector.json` — reads `test.employees` table and publishes to the `employees` Kafka topic.

```bash
curl -s -X POST http://localhost:8083/connectors \
  -H "Content-Type: application/json" \
  -d @source_connector.json
```

Check status:

```bash
curl -s http://127.0.0.1:8083/connectors/sample_source_connector/status
```

Generate data in PostgreSQL and watch it flow into Kafka:

```bash
docker-compose exec postgres bash -c 'psql -U $POSTGRES_USER $POSTGRES_DB -c "SELECT insert_record() FROM GENERATE_SERIES(1, 10);"'
```

Verify records in the database:

```bash
docker-compose exec postgres bash -c 'psql -U $POSTGRES_USER $POSTGRES_DB -c "SELECT count(*) FROM test.employees;"'
```

Check the `employees` Kafka topic has received the records:

```bash
docker-compose exec broker kafka-console-consumer \
  --bootstrap-server broker:29092 \
  --topic employees \
  --from-beginning \
  --max-messages 5
```

---

## Tear Down

```bash
docker-compose down
```
