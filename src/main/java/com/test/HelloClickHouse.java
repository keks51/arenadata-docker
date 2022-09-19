package com.test;

import com.clickhouse.client.ClickHouseClient;
import com.clickhouse.jdbc.ClickHouseConnection;
import com.clickhouse.jdbc.ClickHouseDataSource;

import java.sql.*;
import java.util.Properties;
import java.util.ServiceLoader;

import com.clickhouse.jdbc.ClickHouseDriver;
import com.clickhouse.client.config.ClickHouseClientOption;
import com.clickhouse.client.config.ClickHouseOption;
import com.clickhouse.client.ClickHouseConfig;
//import com.clickhouse.client.data.ClickHouseLZ4InputStream;
// CREATE USER root HOST ANY IDENTIFIED WITH sha256_password BY 'root';
// CREATE DATABASE test123;
// GRANT SELECT ON system.* TO root;
// GRANT SELECT ON test123.* TO root;
// GRANT SELECT ON test.* TO root;

public class HelloClickHouse {

//    -Dchc_clickhouse_cli_path=/Users/Aleksei_Gomziakov/IdeaProjects/arenadata-docker/click_client/clickhouse
    public static void main(String[] args) throws Exception {
        for (ClickHouseClient c : ServiceLoader.load(ClickHouseClient.class, HelloClickHouse.class.getClassLoader())) {
            System.out.println(c);
        }
//        "CHC_CLICKHOUSE_CLI_PATH=/Users/Aleksei_Gomziakov/IdeaProjects/arenadata-docker/click_client/clickhouse"
        jdbcRun("jdbc:ch:http://localhost:8123/default?user=root&password=root&connect_timeout=120000&socket_timeout=300000&session_timeout=300000&&retry=10&failover=10");
//        jdbcRun("jdbc:ch:tcp://localhost:9000/default?user=root&password=root&clickhouse_cli_path=/Users/Aleksei_Gomziakov/IdeaProjects/arenadata-docker/click_client/clickhouse");
//        jdbcRun("jdbc:ch:tcp://localhost:9000/default?user=root&password=root");
//        jdbcRun("jdbc:ch:grpc://localhost:9100?user=root&password=root");

    }

    public static void jdbcRun(String url) throws SQLException {
        Properties properties = new Properties();

        ClickHouseConnection connection = new ClickHouseDriver().connect(url, properties);
        Statement statement = connection.createStatement();
        ResultSet resultSet = statement.executeQuery("select * from system.tables limit 10");
        ResultSetMetaData resultSetMetaData = resultSet.getMetaData();
        int columns = resultSetMetaData.getColumnCount();
        System.out.println("Columns: " + columns);
        while (resultSet.next()) {
            for (int c = 1; c <= columns; c++) {
                System.out.print(resultSetMetaData.getColumnName(c) + ":" + resultSet.getString(c) + (c < columns ? ", " : "\n"));
            }
        }

    }
}