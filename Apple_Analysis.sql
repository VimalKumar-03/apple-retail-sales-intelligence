-- creating database 
CREATE DATABASE IF NOT EXISTS apple_analytics;
USE apple_analytics;



-- creating table before impoting data
-- date table
CREATE TABLE a_date (
  DateID INT PRIMARY KEY,
  DateValue DATE,
  MonthName VARCHAR(10),
  Quarter VARCHAR(5),
  Year INT
);

-- product table
CREATE TABLE a_product (
  ProductID INT PRIMARY KEY,
  Product_Name VARCHAR(150),
  Category VARCHAR(50),
  Model VARCHAR(120),
  Unit_Price DECIMAL(10,2)
);

-- store table
CREATE TABLE a_store (
  StoreID INT PRIMARY KEY,
  Store_Name VARCHAR(150),
  Country VARCHAR(50),
  City VARCHAR(50),
  Store_Type VARCHAR(30)
);

-- sales table
CREATE TABLE sales_fact (
  SaleID INT PRIMARY KEY,
  DateID INT,
  ProductID INT,
  StoreID INT,
  CustomerID INT,
  Quantity INT,
  Total_Sales DECIMAL(12,2),
  
  FOREIGN KEY (DateID) REFERENCES a_date(DateID),
  FOREIGN KEY (ProductID) REFERENCES a_product(ProductID),
  FOREIGN KEY (StoreID) REFERENCES a_store(StoreID)
);

-- understanding data
select * from a_date;
select * from a_product;
select * from a_store;
select * from sales_fact;

SELECT COUNT(*) FROM a_date;
SELECT COUNT(*) FROM a_product;
SELECT COUNT(*) FROM a_store;
SELECT COUNT(*) FROM sales_fact;

describe a_date;
describe a_product;
describe a_store;
describe sales_fact;

--  1: total revenue (overall)
select sum(total_sales) as total_revenue
from sales_fact;

--  2: total quantity sold (overall)
select sum(quantity) as total_quantity
from sales_fact;

--  3: unique customers
select count(distinct customerid) as unique_customers
from sales_fact;

--  4: revenue by product (top 20)
select
  p.productid,
  p.product_name,
  sum(s.total_sales) as revenue
from sales_fact s
join a_product p on s.productid = p.productid
group by p.productid, p.product_name
order by revenue desc
limit 20;

--  5: revenue by category
select
  p.category,
  sum(s.total_sales) as total_revenue
from sales_fact s
join a_product p on s.productid = p.productid
group by p.category
order by total_revenue desc;

--  6: revenue by store (top 20)
select
  st.storeid,
  st.store_name,
  sum(s.total_sales) as total_revenue
from sales_fact s
join a_store st on s.storeid = st.storeid
group by st.storeid, st.store_name
order by total_revenue desc
limit 20;

-- 7: monthly revenue trend (ordered chronologically)
with monthly as (
  select
    d.year,
    month(d.datevalue) as month_num,
    d.monthname,
    sum(s.total_sales) as month_revenue,
    min(d.datevalue) as month_start
  from sales_fact s
  join a_date d on s.dateid = d.dateid
  group by d.year, month_num, d.monthname
)
select year, monthname, month_revenue
from monthly
order by year, month_num;

--  8: top 10 products by revenue
select
  p.product_name,
  sum(s.total_sales) as revenue
from sales_fact s
join a_product p on s.productid = p.productid
group by p.productid, p.product_name
order by revenue desc
limit 10;

--  9: bottom 10 products by revenue
select
  p.product_name,
  sum(s.total_sales) as revenue
from sales_fact s
join a_product p on s.productid = p.productid
group by p.productid, p.product_name
order by revenue asc
limit 10;

-- 10: top 10 stores by revenue
select
  st.store_name,
  sum(s.total_sales) as revenue
from sales_fact s
join a_store st on s.storeid = st.storeid
group by st.storeid, st.store_name
order by revenue desc
limit 10;

-- 11: average order value (aov)
-- shows two common definitions: avg per sale, and sum/count(distinct saleid)
select
  round(avg(total_sales),2) as aov_avg_per_sale,
  round(sum(total_sales)/count(distinct saleid),2) as aov_sum_div_distinct_sales
from sales_fact;

-- 12: highest revenue day
select
  d.datevalue,
  sum(s.total_sales) as day_revenue
from sales_fact s
join a_date d on s.dateid = d.dateid
group by d.datevalue
order by day_revenue desc
limit 1;

-- 13: repeat customers and their spend (customers with >1 purchases)
select
  s.customerid,
  count(*) as num_orders,
  round(sum(s.total_sales),2) as total_spend
from sales_fact s
group by s.customerid
having count(*) > 1
order by total_spend desc;

-- 14: top 5 customers by total spend
select
  s.customerid,
  count(*) as num_orders,
  round(sum(s.total_sales),2) as total_spend
from sales_fact s
group by s.customerid
order by total_spend desc
limit 5;

-- 15: product ranking within category (dense_rank)
with product_revenue as (
  select
    p.category,
    p.product_name,
    sum(s.total_sales) as revenue
  from sales_fact s
  join a_product p on s.productid = p.productid
  group by p.category, p.product_name
)
select
  category,
  product_name,
  revenue,
  dense_rank() over (partition by category order by revenue desc) as rank_in_category
from product_revenue
order by category, rank_in_category;

-- 16: month-over-month (mom) revenue growth percentage
with monthly as (
  select
    d.year,
    month(d.datevalue) as month_num,
    d.monthname,
    sum(s.total_sales) as revenue
  from sales_fact s
  join a_date d on s.dateid = d.dateid
  group by d.year, month_num, d.monthname
)
select
  year,
  monthname,
  revenue,
  round(
    (revenue - lag(revenue) over (order by year, month_num)) /
    nullif(lag(revenue) over (order by year, month_num),0) * 100
  ,2) as mom_growth_pct
from monthly
order by year, month_num;

-- 17: quarter-over-quarter (qoq) revenue growth percentage
with quarterly as (
  select
    d.year,
    d.quarter,
    concat(d.year, '-', d.quarter) as year_quarter,
    sum(s.total_sales) as revenue,
    min(d.datevalue) as q_start
  from sales_fact s
  join a_date d on s.dateid = d.dateid
  group by d.year, d.quarter
)
select
  year,
  quarter,
  revenue,
  round(
    (revenue - lag(revenue) over (order by year, q_start)) /
    nullif(lag(revenue) over (order by year, q_start),0) * 100
  ,2) as qoq_growth_pct
from quarterly
order by year, q_start;

-- 18: products commonly bought by the same customer (co-purchase pairs)
-- counts distinct customers who bought both product_a and product_b (product_a < product_b to avoid duplicates)
select
  p1.product_name as product_a,
  p2.product_name as product_b,
  count(distinct s1.customerid) as co_purchase_count
from sales_fact s1
join sales_fact s2
  on s1.customerid = s2.customerid
  and s1.productid < s2.productid
join a_product p1 on s1.productid = p1.productid
join a_product p2 on s2.productid = p2.productid
group by s1.productid, s2.productid, p1.product_name, p2.product_name
order by co_purchase_count desc
limit 50;

-- this query finds product pairs most commonly owned/purchased by the same customers 
-- (counts distinct customers per pair) by self-joining sales rows per customer and aggregating pairs, 
-- returning the top pairs for cross-sell / bundling insight.











