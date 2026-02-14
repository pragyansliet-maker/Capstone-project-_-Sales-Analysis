select count(orderid)/count(distinct customerid) as avg_order_per_customer
from orders;

select sum(od.unitprice * od.quantity * (1 - od.discount / 100)) as total_order_amount
from orders o
join order_details od
on o.orderid = od.orderid
group by o.orderid;

select sum(od.unitprice * od.quantity * (1 - od.discount / 100)) as total_order_amount,o.customerid
from orders o
join order_details od
on o.orderid = od.orderid
group by o.customerid
having total_order_amount >= 5000;

-- 2. How do customer order patterns vary by city or country?

with order_amount_cte as (
select o.orderid,o.customerid,c.city,c.country,
sum(od.unitprice * od.quantity * (1 - od.discount)) as order_amount
from orders o 
join customers c 
on o.customerid = c.customerid
join order_details od
on o.orderid = od.orderid
group by o.orderid, o.customerid, c.city, c.country
),
customer_summary_cte as (
select country, city, customerid,
count(orderid) as total_orders,
sum(order_amount) as total_spent
from order_amount_cte
group by country, city, customerid
)
select country, city,
avg(total_orders) as avg_order_per_customer,
avg(total_spent) as avg_customer_spend
from customer_summary_cte
group by country, city
order by avg_order_per_customer desc;

-- Can we cluster customers based on total spend, order count, and preferred categories?
-- Total spend and order count per customer
with customer_spend as (
select o.customerid,
count(distinct o.orderid) as order_count,
sum(od.quantity * od.unitprice * (1 - od.discount)) as total_spend
from orders o 
join order_details od on o.orderid = od.orderid
group by o.customerid
)
select * from customer_spend;
-- preferred category per customer
with preferred_category as (
select o.customerid, ct.categoryname,
sum(od.quantity * od.unitprice * (1 - od.discount)) as category_spend
from orders o 
join order_details od on o.orderid = od.orderid
join products p on od.productid = p.productid
join categories ct on p.categoryid = ct.categoryid
group by o.customerid, ct.categoryname
),
ranked_category as (
select *,
row_number() over (
partition by customerid
order by category_spend desc 
) as rn
from preferred_category
)
select customerid, categoryname as customer_preferred_category
from ranked_category
where rn = 1;
-- Which product categories or products contribute most to order revenue?
select
ct.categoryname,
round(sum(od.unitprice * od.quantity * (1 - discount)), 2) as total_revenue
from order_details od
join products p 
on od.productid = p.productid
join categories ct
on p.categoryid = ct.categoryid
group by ct.categoryname
order by total_revenue desc
limit 10;
 -- Are there any correlations between orders and customer location or product category?
-- Orders vs Customer location
select
c.country,
count(distinct o.orderid) as total_orders
from orders o 
join customers c 
on o.customerid = c.customerid
group by c.country
order by total_orders desc;
-- Product category vs location
select
c.country,
ct.categoryname,
count(distinct o.orderid) as order_count
from orders o 
join order_details od on o.orderid = od.orderid
join products p on od.productid = p.productid
join categories ct on p.categoryid = ct.categoryid
join customers c on o.customerid = c.customerid
group by c.country, ct.categoryname
order by c.country, order_count desc;
-- How frequently do different customer segments place orders?
with order_dates as (
select
customerid,
orderdate,
lag(orderdate) over (partition by customerid order by orderdate) as pre_order_date
from orders
),
order_gaps as (
select
customerid,
datediff(orderdate, lag(orderdate) over (
partition by customerid 
order by orderdate
)
) as pre_order_date
from order_dates
),
customer_segments as (
select o.customerid,
case
when count(distinct o.orderid) = 1 then 'one_time buyers'
when count(distinct o.orderid) between 3 and 6 then 'occasional buyers'
when count(distinct o.orderid) between 7 and 10 then 'frequent buyers'
else 'loyal customers'
end as customer_segment
from orders o 
group by o.customerid
)
select
cs.customer_segment,
round(avg(og.pre_order_date), 1) as avg_pre_order_date
from order_gaps og 
join customer_segments cs
on og.customerid = cs.customerid
group by cs.customer_segment
order by avg_pre_order_date;
-- What is the geographic and title-wise distribution of employees?
select country, city,
count(*) as employee_count
from employees
group by country, city
order by country, employee_count;
-- What trends can we observe in hire dates across employee titles?
select title as job_title,
year(hiredate) as hire_year,
month(hiredate) as hire_month,
count(*) as employee_hires
from employees
group by job_title, year(hiredate), month(hiredate)
order by job_title, hire_year, hire_month;
-- What patterns exist in employee title and courtesy title distributions?
select title as job_title,
titleofcourtesy,
count(*) as employee_count
from employees
group by job_title, titleofcourtesy
order by job_title, employee_count desc;
--  Are there correlations between product pricing, stock levels, and sales performance?
select 
productname,
unitprice,
unitsinstock,
rank() over (order by unitprice desc) as price_rank
from (
select p.productname,
p.unitprice,
p.unitsinstock,
sum(od.quantity) as total_units_sold
from products p 
join order_details od on p.productid = od.productid
group by p.productname, p.unitprice, p.unitsinstock
) t;
-- How does product demand change over months or seasons?
select p.productname,
year(o.orderdate) as order_year,
month(o.orderdate) as order_month,
sum(od.quantity) as units_sold
from orders o 
join order_details od on o.orderid = od.orderid
join products p on od.productid = p.productid
group by 
p.productname,
year(o.orderdate),
month(o.orderdate)
order by p.productname,
order_year,
order_month;
-- Can we identify anomalies in product sales or revenue performance?
-- compare daily sales vs average sales
 with daily_sales as (
 select 
 o.orderdate,
round( sum(od.unitprice * od.quantity * (1 - od.discount)) , 2) as revenue
 from orders o 
 join order_details od on o.orderid = od.orderid
 group by o.orderdate
 )
 select *,
 avg(revenue) over () as avg_revenue,
 revenue - avg(revenue) over () as difference_in_revenue
 from daily_sales;
 -- Are there any regional trends in supplier distribution and pricing?
 select 
 s.country, 
 round(avg(p.unitprice), 2) as avg_price
 from suppliers s 
 join products p 
 on s.supplierid = p.supplierid
 group by s.country
 order by avg_price desc;
 -- supplier distribution by region
 select 
 country,
 count(supplierid) as supplier_count
 from suppliers
 group by country
 order by supplier_count desc;
 -- How are suppliers distributed across different product categories?
 select
 ct.categoryname,
 count(distinct s.supplierid) as supplier_count
 from suppliers s 
 join products p 
 on s.supplierid = p.supplierid
 join categories ct
 on p.categoryid = ct.categoryid
 group by ct.categoryname
 order by supplier_count desc;
-- How do supplier pricing and categories relate across different regions?
select 
s.country,
ct.categoryname,
min(p.unitprice) as min_price,
max(p.unitprice) as max_price
from suppliers s 
join products p 
on s.supplierid = p.supplierid
join categories ct 
on p.categoryid = ct.categoryid
group by s.country,
ct.categoryname;


 








 

