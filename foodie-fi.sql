-- A. Customer Journey
/* Based off the 8 sample customers provided in the sample from the subscriptions table, 
write a brief description about each customer’s onboarding journey.*/
with cte as (
	select customer_id, start_date, lead(start_date) over (partition by customer_id) as end_date,
		p.plan_name, price
	from subscriptions s
	join plans p using(plan_id)
	where customer_id in (1,2,11,13,15,16,18,19)
)
select *, datediff(end_date,start_date) as subscription
from cte;

/*Customer 1:
Started with a trial subscription from August 1 to August 8.
Upgraded to the "basic monthly" plan starting from August 8.
The price for the basic monthly plan is $9.90.

Customer 2:
Started with a trial subscription from September 20 to September 27.
Upgraded to the "pro annual" plan starting from September 27.
The price for the pro annual plan is $199.00.

Customer 11:
Started with a trial subscription from November 19 to November 26.
No further information is available about this customer's subscription.

Customer 13:
Started with a trial subscription from December 15 to December 22.
Upgraded to the "basic monthly" plan starting from December 22.
Subsequently upgraded to the "pro monthly" plan, but no end date is specified.
The price for the basic monthly plan is $9.90, and the price for the pro monthly plan is $19.90.

Customer 15:
Started with a trial subscription from March 17 to March 24.
Upgraded to the "pro monthly" plan starting from March 24.
Subsequently churned (canceled the subscription) at an unspecified date.
The price for the pro monthly plan is $19.90.

Customer 16:
Started with a trial subscription from May 31 to June 7.
Upgraded to the "basic monthly" plan starting from June 7.
Subsequently upgraded to the "pro annual" plan, but no end date is specified.
The price for the basic monthly plan is $9.90, and the price for the pro annual plan is $199.00.

Customer 18:
Started with a trial subscription from July 6 to July 13.
Upgraded to the "pro monthly" plan starting from July 13.
No end date is specified for the pro monthly plan.
The price for the pro monthly plan is $19.90.

Customer 19:
Started with a trial subscription from June 22 to June 29.
Upgraded to the "pro monthly" plan starting from June 29.
Subsequently upgraded to the "pro annual" plan, but no end date is specified.
The price for the pro monthly plan is $19.90, and the price for the pro annual plan is $199.00.*/

-- B. Data Analysis Questions
/* 1. How many customers has Foodie-Fi ever had? */
select count(distinct customer_id) as no_of_customers
from subscriptions;

/* 2. What is the monthly distribution of trial plan start_date values for our dataset - 
use the start of the month as the group by value */
select month(start_date) as month_num, 
	monthname(s.start_date) as month_name, count(*) as distribution 
from subscriptions s
inner join plans p using(plan_id)
where p.plan_name = "trial"
group by 1,2 order by 1;

/* 3. What plan start_date values occur after the year 2020 for our dataset? 
Show the breakdown by count of events for each plan_name */
select p.plan_name, count(*) as count_of_events
from subscriptions s
inner join plans p using(plan_id)
where year(start_date) > 2020
group by 1 order by 2 desc;

/* 4. What is the customer count and percentage of customers who have churned rounded to 1 decimal place? */
with cte as(
	select sum(case when p.plan_name = "churn" then 1 else 0 end) as churned_customer
	from subscriptions s
	left join plans p using(plan_id))
select churned_customer, 
	round(churned_customer*100/(select count(distinct customer_id) from subscriptions),1) as churned_percent
from cte;

/* 5. How many customers have churned straight after their initial free trial - 
what percentage is this rounded to the nearest whole number? */
with cte2 as (
	with cte1 as (
		select s.customer_id, p.plan_name, p.plan_id,
			rank() over(partition by s.customer_id order by p.plan_id) as plan_rank
		from subscriptions s
		left join plans p using(plan_id))
	select sum(case when plan_name = "churn" and plan_rank = 2 then 1 else 0 end) as churn_customers,
		(select count(distinct customer_id) from subscriptions) as total_customers
	from cte1)
select churn_customers, round(churn_customers*100/total_customers) as percent
from cte2;

/* 6. What is the number and percentage of customer plans after their initial free trial? */
with cte as(
	select *,
		rank() over(partition by customer_id order by start_date) as plan_rank,
        (select count(distinct customer_id) from subscriptions) as total_customers
	from subscriptions)
select plan_name, count(*) as customer_cnt,
	round(count(*)*100/total_customers,2) as customer_percentage
from cte c
inner join plans p using(plan_id)
where plan_rank = 2
group by 1 order by 2 desc;

/* 7. What is the customer count and percentage breakdown of all 5 plan_name values at 2020-12-31? */
with cte as (
select customer_id, plan_id, start_date,
		lead(start_date) over(partition by customer_id order by start_date) as end_date
from subscriptions
where year(start_date) = 2020)

select plan_name, count(distinct customer_id) as customers,
	round(100*count(distinct customer_id) / (select count(distinct customer_id) from subscriptions),1) as percentage
from cte c
inner join plans p using(plan_id)
where end_date is null
group by plan_name order by 2;

/* 8. How many customers have upgraded to an annual plan in 2020? */
select count(distinct customer_id) as customer_cnt
from subscriptions s
inner join plans p using(plan_id)
where year(start_date) = 2020 and plan_name = "pro annual";

/* 9. How many days on average does it take for a customer to an annual plan from the day they join Foodie-Fi? */

with trial_tb as (
	select customer_id, start_date as trial_start_date, plan_name
	from subscriptions s
	inner join plans p using(plan_id)
	where plan_name = "trial"),
annual_tb as (
	select customer_id, start_date as annual_start_date, plan_name
	from subscriptions s
	inner join plans p using(plan_id)
	where plan_name = "pro annual")
	select round(avg(datediff(annual_start_date, trial_start_date))) as average_days
	from trial_tb t1
	inner join annual_tb t2 using(customer_id);

/* 10. Can you further breakdown this average value into 30 day periods (i.e. 0-30 days, 31-60 days etc) */
with trial_tb as (
	select customer_id, start_date as trial_start_date, plan_name
	from subscriptions s
	inner join plans p using(plan_id)
	where plan_name = "trial"),
annual_tb as (
	select customer_id, start_date as annual_start_date, plan_name
	from subscriptions s
	inner join plans p using(plan_id)
	where plan_name = "pro annual"),
cte as (
	select floor(datediff(annual_start_date, trial_start_date)/30) as num,
		datediff(annual_start_date, trial_start_date) as days
	from trial_tb t1
    inner join annual_tb t2 using(customer_id))
select concat((num*30)+1," - ",(num+1)*30," days") as day_breakdown, count(days)
from cte
group by num
order by num;
    
/* 11. How many customers downgraded from a pro monthly to a basic monthly plan in 2020? */
with downgrade as (
	select customer_id, start_date, plan_name as first_plan,
		lead(plan_name,1) over(partition by customer_id order by start_date) as next_plan
	from subscriptions s
	inner join plans p using(plan_id)
	where year(start_date) = 2020)
select count(*) as customer_cnt
from downgrade
where first_plan = "pro monthly" and next_plan = "basic_monthly";

-- C. Challenge Payment Question

/* The Foodie-Fi team wants you to create a new payments table for the year 2020 that includes
amounts paid by each customer in the subscriptions table with the following requirements:

1. monthly payments always occur on the same day of month as the original start_date of any monthly paid plan
2. upgrades from basic to monthly or pro plans are reduced by the current paid 
amount in that month and start immediately
3. upgrades from pro monthly to pro annual are paid at the end of the current billing period 
and also starts at the end of the month period
4. once a customer churns they will no longer make payments*/

/* Hint:
To resolve this challenge, we would take the following steps:

i) Get only subscriptions that were made in the year 2020
ii) Remove trial and churn plans since no payments were made for these
iii) Join plans table to get plan name and price.
iv) Use the lead window function to get the start date, if it exists, 
of the next plan a user migrated to. We’ll call that date, end_date.*/

-- Step 1:
select s.customer_id, s.plan_id, p.plan_name, s.start_date, 
	lead(start_date) over(partition by customer_id order by start_date, plan_id) as end_date,
    p.price as amount
from subscriptions s
inner join plans p using(plan_id)
where year(start_date) = 2020 and plan_name not in('trial', 'churn');

/* v) End_date column has [null] values in some rows which indicates that is 
the last plan the user was on for that year (otherwise it would have had a 
next plan start date). So we would replace [null] values with the last day of the year 2020.*/

-- Step 2:
with cte as (
	select s.customer_id, s.plan_id, p.plan_name, s.start_date, 
		lead(start_date) over(partition by customer_id order by start_date, plan_id) as end_date,
		p.price as amount
	from subscriptions s
	inner join plans p using(plan_id)
	where year(start_date) = 2020 and plan_name not in('trial', 'churn'))
select customer_id, plan_id, plan_name, start_date,
	ifnull(end_date, '2020-12-31') as end_date, amount
from cte;

/* vi) Hence, we will write a recursive CTE query that will create new rows for users 
on either of the monthly plans by incrementing the start_date by a month as long 
as the end_date is still greater than start_date + 1 month. 

vii) To implement this, we will deduct the money paid for the basic plan from the 
pro plans as long as the user upgraded from the basic plan.

viii) We will also include add a rank function to order payments by start_date for each customer

ix) Finally, we would copy the result of our query to a table called payments
using the create table [TABLE_NAME] as command.*/

-- Step 3:
create table payments as
(with recursive cte as (
	select s.customer_id, s.plan_id, p.plan_name, s.start_date, 
		lead(start_date) over(partition by customer_id order by start_date, plan_id) as end_date,
		p.price as amount
	from subscriptions s
	inner join plans p using(plan_id)
	where year(start_date) = 2020 and plan_name not in('trial', 'churn')),
cte1 as (
	select customer_id, plan_id, plan_name, start_date,
		ifnull(end_date, '2020-12-31') as end_date, amount
	from cte),
cte2 as (
	select customer_id, plan_id, plan_name, start_date, end_date, amount
	from cte1
    union all
	select customer_id, plan_id, plan_name, 
		date(start_date + interval 1 month) as start_date,
        end_date, amount
	from cte2
    where end_date > date(start_date + interval 1 month) and plan_name <> 'pro annual'),
cte3 as (
	select *, lag(plan_id) over(partition by customer_id order by start_date) as last_plan,
		lag(amount) over(partition by customer_id order by start_date) as last_amount_paid,
        rank() over(partition by customer_id order by start_date) as payment_order
	from cte2
    order by 1,4)
select customer_id, plan_id, plan_name, start_date as payment_date,
	(case when plan_id in (2,3) and last_plan = 1 then amount - last_amount_paid else amount end) as amount,
    payment_order
from cte3);