PXF

1) templates are stored in /usr/local/pxf/templates/
2) jdbc drivers should be stored in /usr/local/pxf/lib/ on each segment host
   docker cp clickhouse-jdbc-0.3.2.jar sdw1:/data/pxf-base/lib/click_jdbc/
   docker cp clickhouse-jdbc-0.3.2.jar sdw2:/data/pxf-base/lib/click_jdbc/
   docker cp clickhouse-jdbc-0.3.2.jar sdw3:/data/pxf-base/lib/click_jdbc/
   docker cp clickhouse-client-0.3.2.jar sdw1:/data/pxf-base/lib/click_jdbc/
   docker cp clickhouse-client-0.3.2.jar sdw2:/data/pxf-base/lib/click_jdbc/
   docker cp clickhouse-client-0.3.2.jar sdw3:/data/pxf-base/lib/click_jdbc/
   docker cp clickhouse-http-client-0.3.2.jar sdw1:/data/pxf-base/lib/click_jdbc/
   docker cp clickhouse-http-client-0.3.2.jar sdw2:/data/pxf-base/lib/click_jdbc/
   docker cp clickhouse-http-client-0.3.2.jar sdw3:/data/pxf-base/lib/click_jdbc/
   
   docker cp clickhouse-http-client-0.3.2.jar mdw:/data/pxf-base/lib/click_jdbc/
   docker cp clickhouse-jdbc-0.3.2.jar mdw:/data/pxf-base/lib/click_jdbc/
   docker cp clickhouse-client-0.3.2.jar mdw:/data/pxf-base/lib/click_jdbc/
   docker cp lz4-java-1.8.0.jar mdw:/data/pxf-base/lib/click_jdbc/
   chown -R gpadmin:gpadmin /data/pxf-base/lib/
3) profiles should be stored in /data/pxf-base/servers/<profile_dir>/<file-name>
   docker cp jdbc-site.xml mdw:/data/pxf-base/servers/click_jdbc
   docker cp jdbc-site.xml sdw1:/data/pxf-base/servers/click_jdbc
   docker cp jdbc-site.xml sdw2:/data/pxf-base/servers/click_jdbc
   docker cp jdbc-site.xml sdw3:/data/pxf-base/servers/click_jdbc
   chown -R gpadmin:gpadmin /data/pxf-base/servers/

4) chown -R gpadmin:gpadmin /data/pxf-base/lib
5) pxf cluster sync
6) psql: CREATE EXTENSION pxf;

CREATE TABLE table11 (id1 int, id2 int, gen text, now timestamp without time zone)
WITH (appendonly=true, orientation=column, compresstype=zstd, compresslevel=1)
DISTRIBUTED BY (id1);

create index table11_btree_id1 on table11 using btree (id1);

insert into table11 select gen, gen, 'text' || gen::text, now () from generate_series (1,40000) gen;

DROP EXTERNAL TABLE if exists table_11_pxf_read;

CREATE EXTERNAL TABLE table_11_pxf_read(like table11) 
LOCATION ('pxf://test123.table11?PROFILE=Jdbc&JDBC_DRIVER=com.clickhouse.jdbc.ClickHouseDriver&SERVER=click_jdbc')
FORMAT 'CUSTOM' (FORMATTER='pxfwritable_import');

CREATE EXTERNAL TABLE table_11_pxf_read(like table11)
LOCATION ('pxf://test123.table11?PROFILE=Jdbc&JDBC_DRIVER=com.clickhouse.jdbc.ClickHouseDriver&SERVER=click_jdbc')
FORMAT 'text' encoding 'utf8';

EXPLAIN ANALYZE SELECT COUNT(*) FROM table_11_pxf_read;

LOCATION ('pxf://test123.table11?PROFILE=Jdbc&JDBC_DRIVER=org.postgresql.Driver&DB_URL=jdbc:postgresql://mdw:5432/adb&USER=gpadmin')

set client_min_messages=LOG;

CREATE TABLE table11 (id1 int, id2 int, gen text, now timestamp without time zone)
WITH (appendonly=true, orientation=column, compresstype=zstd, compresslevel=1)
DISTRIBUTED BY (id1);

drop table test123.table11;
create table test123.table11 (id1 Int32, id2 Int32, gen String, now DateTime)
ENGINE = MergeTree()
PRIMARY KEY id1;

INSERT INTO test123.table11 SELECT
number, number, toValidUTF8(concat('test_val', (toString(number)))), toDate((number % 20) + 17897)
FROM numbers(1000000);