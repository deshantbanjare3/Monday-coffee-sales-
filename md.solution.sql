create database monday_coffee_db;
use monday_coffee_db;

-- Monday Coffee SCHEMAS

DROP TABLE IF EXISTS sales;
DROP TABLE IF EXISTS customers;
DROP TABLE IF EXISTS products;
DROP TABLE IF EXISTS city;

-- Import Rules
-- 1st import to city
-- 2nd import to products
-- 3rd import to customers
-- 4th import to sales


CREATE TABLE city
(
	city_id	INT PRIMARY KEY,
	city_name VARCHAR(15),	
	population	BIGINT,
	estimated_rent	FLOAT,
	city_rank INT
);

CREATE TABLE customers
(
	customer_id INT PRIMARY KEY,	
	customer_name VARCHAR(25),	
	city_id INT,
	CONSTRAINT fk_city FOREIGN KEY (city_id) REFERENCES city(city_id)
);


CREATE TABLE products
(
	product_id	INT PRIMARY KEY,
	product_name VARCHAR(35),	
	Price float
);


CREATE TABLE sales
(
	sale_id	INT PRIMARY KEY,
	sale_date	date,
	product_id	INT,
	customer_id	INT,
	total FLOAT,
	rating INT,
	CONSTRAINT fk_products FOREIGN KEY (product_id) REFERENCES products(product_id),
	CONSTRAINT fk_customers FOREIGN KEY (customer_id) REFERENCES customers(customer_id) 
);

-- END of SCHEMAS

select * from city;
select * from customers;
select * from products;
select * from sales;


-- Reports & Data analysis 

-- ## Objective
-- The goal of this project is to analyze the sales data of Monday Coffee, a company that has been selling its products online since January 2023, and to recommend the top three major cities in India for opening new coffee shop locations based on consumer demand and sales performance.

--  1. **Coffee Consumers Count**  
--  How many people in each city are estimated to consume coffee, given that 25% of the population does?

select 
city_name,
round((population*.25)/1000000,2) as estimated_coffee_consumers_in_millions 
from city
order by 2 desc;

-- 2. **Total Revenue from Coffee Sales**  
-- What is the total revenue generated from coffee sales across all cities in the last quarter of 2023?

select
	city_name,
	sum(s.total) as total_revenue
from sales as s 
join customers as c
on s.customer_id=c.customer_id
join city as ci
on ci.city_id=c.city_id
where (extract(year from s.sale_date))=2023
	and
	  (extract(quarter from s.sale_date))=4
group by city_name
order by total_revenue desc;


-- 3. **Sales Count for Each Product**  
-- How many units of each coffee product have been sold?

select 
product_name,
count(sale_id) as product_quantity_sold
from sales as s
left join products as p
on s.product_id=p.product_id
group by product_name
order by product_quantity_sold desc;


-- 4. **Average Sales Amount per City**  
-- What is the average sales amount per customer in each city?

select
	city_name,
    round((sum(s.total)/count(distinct c.customer_id)),2) as average_sale_per_cust
from sales as s 
join customers as c
on s.customer_id=c.customer_id
join city as ci
on ci.city_id=c.city_id
group by city_name
order by 2 desc;

-- 5. **City Population and Coffee Consumers**  
-- Provide a list of cities along with their populations and estimated coffee consumers.
-- return city name, current consumers, estimated coffee consumers(25%)


with city_table
as
(	
	SELECT 
	ci.city_name,
	ROUND((ci.population * .25) / 1000000, 2) AS estimated_coffee_consumers_in_millions
	FROM city as ci
),
all_table
as
(	
	select
		ci.city_name,
		count(distinct c.customer_id) as unique_customers
	from sales as s 
	join customers as c
	on c.customer_id=s.customer_id
	join city as ci
	on ci.city_id=c.city_id
	group by 1
)
select 
	all_table.city_name,
    city_table.estimated_coffee_consumers_in_millions as estimated_coffee_consumers_in_m,
    all_table.unique_customers as unique_cx
from city_table
join all_table
on city_table.city_name=all_table.city_name;

-- Q6
-- Top selling products by city
-- What are the top 3 selling product based on sales volume?

select *
from 
(
	select 
		ci.city_name,
		product_name,
		count(s.sale_id) as order_volume,
		dense_rank() over(partition by ci.city_name order by count(s.sale_id) desc) as rank1
	from sales as s 
	join products as p 
	on p.product_id = s.product_id 
	join customers as c
	on c.customer_id = s.customer_id
	join city as ci
	on ci.city_id = c.city_id 
	group by 1,2
)
as t1
where rank1 <=3;

-- Q7
-- Customer segmentation by city
-- How many unique costumers are there in each city who have purchased coffee products?

	
select 
	ci.city_name,
	count(distinct c.customer_id) as distinct_customers
from customers as c 
join city as ci
on ci.city_id=c.city_id
join sales as s
on s.customer_id = c.customer_id
join products as p
on p.product_id=s.product_id
where s.product_id <= 14
group by 1 
order by 1;


-- Q8
-- Average sale & rent 
-- Find each city and their average sale per customer and average rent per customer

with city_table 
as
(	
	select
		city_name,
		count(distinct c.customer_id) as dist_cx,
		round(sum(s.total)/count(distinct c.customer_id),2) as average_sale_per_cust
	from sales as s 
	join customers as c
	on s.customer_id=c.customer_id
	join city as ci
	on ci.city_id=c.city_id
	group by 1
),
city_rent
as
(
	select 
		city_name,
		estimated_rent
	from city as c
	order by 1
)
select 
	ct.city_name,
    ct.average_sale_per_cust,
    round(cr.estimated_rent/ct.dist_cx,2) as average_rent_per_cust
from city_table as ct
inner join city_rent as cr
on cr.city_name=ct.city_name;

-- Q9
-- Monthly sales Growth
-- Sales growth rate: Calculate sales percentage growth (or decline) in sales in different time period (monthly)
-- in each city

with monthly_sales
as
(
	select 
		ci.city_name,
		extract(year from sale_date) as year,  
		extract(month from sale_date) as month,
		sum(s.total) as month_sale
	from sales as s
	join customers as c
	on c.customer_id = s.customer_id
	join city as ci
	on ci.city_id = c.city_id
	group by 1, 3, 2
	order by 1, 2, 3
),
growth_ratio
as
(
		select 
			city_name,
			year,
			month,
			month_sale as current_month_sale,
			lag(month_sale,1) over(partition by city_name order by year, month) as previous_month_sale
		from monthly_sales
)
select 
	city_name,
    year,
    month,
    current_month_sale,
    previous_month_sale,
    round(((current_month_sale-previous_month_sale)/previous_month_sale)*100,2) as growth_rate
from growth_ratio
where previous_month_sale is not null;

-- Q10
-- Market potential analysis
-- Identify top 3 city based on highest sale, return city name, total sale, total customers, total rent,
-- estimated coffee consumers

with city_table 
as
(	
	select
		city_name,
        round(sum(s.total),2) as total_sale,
		count(distinct c.customer_id) as dist_cx,
		round(sum(s.total)/count(distinct c.customer_id),2) as average_sale_per_cust
	from sales as s 
	join customers as c
	on s.customer_id=c.customer_id
	join city as ci
	on ci.city_id=c.city_id
	group by 1
),
city_rent
as
(
	select 
		city_name,
		estimated_rent,
        population
	from city as c
)
select 
	ct.city_name,
    ct.total_sale,
    ct.average_sale_per_cust,
    ct.dist_cx as total_customer,
    cr.estimated_rent as total_rent,
    round(cr.estimated_rent/ct.dist_cx,2) as average_rent_per_cust,
    round((cr.population*.25)/1000000,2) as estimated_coffee_consumers_in_millions
from city_table as ct
inner join city_rent as cr
on cr.city_name=ct.city_name
order by 2 desc;

/* Recommandation 
City 1:Pune 
	1. Highest revenue
	2. Average sale per customer is high  
	3. Average rent per customer is also very less
    
City 2:Delhi 
	1. Highest number of coffee consumers
	2. Less average rent per customer 
	3. Total customer is also high 

City 3:Jaipur
	1. Lowest average rent per customer 
	2. Highest total customers
	3. Total sale is also good 