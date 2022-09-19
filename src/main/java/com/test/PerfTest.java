package com.test;
import com.clickhouse.jdbc.ClickHouseConnection;
import com.clickhouse.jdbc.ClickHouseDriver;

import java.sql.*;
import java.time.Duration;
import java.time.Instant;
import java.util.ArrayList;
import java.util.Properties;

public class PerfTest {

    public static void main(String[] args) throws SQLException {

        ArrayList<Integer> arr = new ArrayList<>();
//        arr.add(1000);
//        arr.add(10_000);
//        arr.add(50_000);
        arr.add(100_000);
//        arr.add(500_000);
//        arr.add(1_000_000);
        for(int batchSize: arr) {
            clearClick();
            System.out.println();
            System.out.println("RunningBatch: " + batchSize);
            Instant start = Instant.now();
            createGreenTableHttp(batchSize);

            Instant curTime = Instant.now();
            long timeTaken = Duration.between(start, curTime).toMillis() / 1000;
            System.out.println("BatchSize: " + batchSize + ";Sec: " + timeTaken);
        }

    }

    public static void createGreenTableHttp(int batchSize) throws SQLException {
        Connection db = DriverManager.getConnection("jdbc:pivotal:greenplum://localhost:5432;USER=gpadmin;PASSWORD=gpadmin");
        Statement st = db.createStatement();
        String setSql = "set client_min_messages=LOG;";
        String dropSql = "drop  external  table if exists sales_dm_write_http;";
        String createSql = "CREATE WRITABLE EXTERNAL TABLE sales_dm_write_http(\n" +
                "sales_date date,\n" +
                "sales_rub  float,\n" +
                "sales_count  int,\n" +
                "sales_income float,\n" +
                "store_id int,\n" +
                "store_region text,\n" +
                "store_name text,\n" +
                "product_id text,\n" +
                "product_category text,\n" +
                "product_name text\n" +
                ")\n" +
                "LOCATION ('pxf://test.sales_dm?PROFILE=Jdbc&JDBC_DRIVER=com.clickhouse.jdbc.ClickHouseDriver&SERVER=click_jdbc&DB_URL=jdbc:ch:http://host.docker.internal:8123/test&user=root&password=root&BATCH_SIZE=" + batchSize +"&connect_timeout=120000&socket_timeout=300000&session_timeout=300000&retry=20&failover=20')\n" +
                "FORMAT 'CUSTOM' (FORMATTER='pxfwritable_export');";
        String insertQuery = "INSERT INTO sales_dm_write_http(select * from sales_dm);";
        System.out.println("Running: " + dropSql);
        st.execute(setSql);
        st.execute(dropSql);
        System.out.println("Running: " + createSql);
        st.execute(createSql);
        System.out.println("Running: " + insertQuery);
        st.execute(insertQuery);
    }

    public static void clearClick() throws SQLException {
        String url = "jdbc:ch:http://localhost:8123/default?user=root&password=root";
        Properties properties = new Properties();
        ClickHouseConnection connection = new ClickHouseDriver().connect(url, properties);
        Statement statement = connection.createStatement();
        statement.execute("truncate table test.sales_dm;");
    }



}
