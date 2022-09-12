PXF

1) templates are stored in /usr/local/pxf/templates/
2) jdbc drivers should be stored in /usr/local/pxf/lib/ on each segment host
   load driver from https://repo1.maven.org/maven2/ru/yandex/clickhouse/clickhouse-jdbc/0.3.2/clickhouse-jdbc-0.3.2-shaded.jar
   docker cp clickhouse-jdbc-0.3.2-shaded.jar mdw:/data/pxf-base/lib/click_jdbc/
   chown -R gpadmin:gpadmin /data/pxf-base/lib/
3) profiles should be stored in /data/pxf-base/servers/<profile_dir>/<file-name>
   docker cp jdbc-site.xml mdw:/data/pxf-base/servers/click_jdbc
   chown -R gpadmin:gpadmin /data/pxf-base/servers/

4) chown -R gpadmin:gpadmin /data/pxf-base/lib
5) pxf cluster sync
6) psql: CREATE EXTENSION pxf;



READ FROM CLICKHOUSE

CLICKHOUSE
CREATE USER root HOST ANY IDENTIFIED WITH sha256_password BY 'root';
GRANT SELECT ON test.* TO root;
create database test;
drop table if exists test.click_table;
create table test.click_table (id1 Int32, id2 Int32, gen String, now DateTime)
ENGINE = MergeTree()
PRIMARY KEY id1;
INSERT INTO test.click_table SELECT
number, number, toValidUTF8(concat('test_val', (toString(number)))), toDate((number % 20) + 17897)
FROM numbers(1000000);
select count(*) from test.click_table;


GREENPLUM
set client_min_messages=LOG;
CREATE TABLE click_table_schema (id1 int, id2 int, gen text, now timestamp without time zone)
WITH (appendonly=true, orientation=column, compresstype=zstd, compresslevel=1)
DISTRIBUTED BY (id1);
create index click_table_schema_idx1 on click_table_schema using btree (id1);
insert into click_table_schema select gen, gen, 'text' || gen::text, now () from generate_series (1,40000) gen;
select count(*) from click_table_schema;
DROP EXTERNAL TABLE if exists click_table_pxf_read;
CREATE EXTERNAL TABLE click_table_pxf_read(like click_table_schema)
LOCATION ('pxf://test.click_table?PROFILE=Jdbc&JDBC_DRIVER=com.clickhouse.jdbc.ClickHouseDriver&SERVER=click_jdbc&DB_URL=jdbc:clickhouse://host.docker.internal:8123')
FORMAT 'text' encoding 'utf8';
SELECT COUNT(*) FROM click_table_pxf_read;
EXPLAIN ANALYZE SELECT COUNT(*) FROM click_table_pxf_read;


CREATE EXTERNAL TABLE click_table_pxf_read2(like click_table_schema)
LOCATION ('pxf://test.click_table?PROFILE=Jdbc&JDBC_DRIVER=com.clickhouse.jdbc.ClickHouseDriver&SERVER=click_jdbc&DB_URL=jdbc:clickhouse://host.docker.internal:8123')
FORMAT 'text' encoding 'utf8';
SELECT COUNT(*) FROM click_table_pxf_read2;