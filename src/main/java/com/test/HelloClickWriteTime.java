package com.test;

import com.clickhouse.jdbc.ClickHouseConnection;
import com.clickhouse.jdbc.ClickHouseDriver;

import java.sql.ResultSet;
import java.sql.SQLException;
import java.sql.Statement;
import java.time.Duration;
import java.time.Instant;
import java.util.Properties;



public class HelloClickWriteTime {

    public static void main(String[] args) throws Exception {
        Instant start = Instant.now();


        long currentStep = 500_000L;
        long currentLimit = currentStep;

        long limit = 2_000_000L;
        while (currentLimit <= limit) {
            long res = jdbcCount("test", "sales_dm");
            if (res == 0) start = Instant.now();
            System.out.println("Res: " + res);
            if (res >= currentLimit) {
                Instant curTime = Instant.now();
                long timeTaken = Duration.between(start, curTime).toMillis() / 1000;
                System.out.println("Step achieved: " + currentLimit + "rec; " + timeTaken + "sec");
                currentLimit = currentLimit + currentStep;
            }
            Thread.sleep(1000);
        }

        jdbcCount("test", "sales_dm");
    }

    public static long jdbcCount(String database, String table) throws SQLException {
        String url = "jdbc:ch:http://localhost:8123/default?user=root&password=root";
        Properties properties = new Properties();
        ClickHouseConnection connection = new ClickHouseDriver().connect(url, properties);
        Statement statement = connection.createStatement();
        String dbAndTable = database + "." + table;
        ResultSet resultSet = statement.executeQuery("select count(*) from " + dbAndTable + ";");
        resultSet.next();
        long cnt = Long.parseLong(resultSet.getString("count()"));
        return cnt;
    }
}