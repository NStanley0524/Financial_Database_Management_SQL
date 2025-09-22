set search_path to financial_system,public;
-- REPORTING AND ANALYTICS


/*

Here some business questions are going to be answered in order to derive insights from the dataset

*/


-- 1. TOTAL TRANSACTION VOLUME OVER TIME

select date_trunc('month',transaction_date) as month,sum(amount)
from transactions
group by 1
order by 1;

select extract('month' from transaction_date) as Month_number,to_char(transaction_date,'month') as Monthname,sum(amount)
from transactions t
group by Month_number,Monthname
order by Month_number;



-- 2. FRAUDULENT TRANSACTION RATE


select Fraudulent,Non_fraudulent,(Fraudulent::decimal/nullif(Non_fraudulent,0)) * 100 as Percentage
from
(select
count(case when fraud_label = 'Yes' then 1 end) as Fraudulent,
count(case when fraud_label = 'No' then 1 end) as Non_fraudulent
from fraud_labels);




-- 3. MERCHANT LOCATION WITH MOST FRAUDULENT TRANSACTIONS


select t.merchant_city,t.merchant_state,count(*) as Fraudulent_transactions
from transactions t join fraud_labels f
on t.transaction_id = f.transaction_id
where f.fraud_label = 'Yes'
group by t.merchant_city,t.merchant_state
order by Fraudulent_transactions desc;



