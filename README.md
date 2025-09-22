# Financial_Database_Management_SQL
This repository contains a complete end-to-end SQL project built on a large financial transactions dataset. The project demonstrates advanced SQL database engineering concepts such as partitioning, indexing, stored procedures, triggers, materialized views, and business-focused reporting.





## Table of Contents
- [Financial_Database_Management_SQL](#financial_database_management_sql)
- [Project Overview](#project-overview)
- [Project Goals](#project-goals)
- [Aim of Project](#aim-of-project)
- [Who This Project is For](#who-this-project-is-for)
- [Tools Used](#tools-used)
- [Data Source and Processing](#data-source-and-processing)
- [Database Design](#database-design)
- [Database Optimization](#database-optimization)
  - [Indexes](#indexes)
  - [Partitioning](#partitioning)
  - [Materialized Views](#materialized-views)
- [Stored Procedures, Views and Triggers (Automation and Integrity)](#stored-procedures-views-and-triggers-automation-and-integrity)
  - [Stored Procedures](#stored-procedures)
  - [Triggers](#triggers)
  - [Views](#views)
- [Reporting & Analytics](#reporting--analytics)
- [How to Run](#how-to-run)






## Project Overview
The main objective of this project was to take a raw financial dataset and transform it into a high-performing, analytics-ready database. By implementing advanced SQL techniques, the project showcases how to design, optimize, and query a large dataset efficiently.  
Key highlights include:  
- Building normalized tables for users, cards, merchants, transactions, and fraud labels.  
- Handling **13 million transaction rows** with indexing, partitioning, and materialized views.  
- Automating checks with views, stored procedures and triggers for fraud detection and credit limits.  
- Answering real-world business questions through SQL-based reporting and analytics. 



## Project Goals
1. **Performance**: Optimize queries over millions of rows using indexes and partitioning.  
2. **Data Integrity**: Ensure data consistency and enforce business rules with triggers.  
3. **Automation**: Use stored procedures for reusable analytics.  
4. **Analytics**: Provide insights into fraud detection, customer spending, and merchant activity.  
5. **Documentation**: Build a project that is well-structured, transparent, and reproducible.  



## Aim of Project
The aim was not just to practice SQL queries, but to simulate a **real-world financial analytics database** where:  
- Data is large and needs optimization.  
- Business queries need to run fast.  
- Analysts can quickly retrieve insights through pre-defined views and procedures.  



## Who This Project is For
- Fintech companies and payment processors (e.g., PayPal, Stripe, Paystack, Flutterwave, Interswitch,Moniepoint,FairMoney) looking to enforce business rules like fraud detection and credit-limit monitoring at the database level.

- Banks and financial institutions that need to process millions of daily transactions securely and efficiently.

- Students and learners who want to see how SQL can be applied to large-scale financial data.

- Data analysts and data engineers looking for templates on reporting queries, partitioning, and materialized views.

- Database administrators (DBAs) interested in practical optimization techniques on large datasets.




## Tools Used

The following tools were used for the project

- PostgreSQL
- Python
- Jupyter Notebook




## Data Source and Processing
The dataset for this project was gotten from [Kaggle](https://www.kaggle.com/datasets/computingvictor/transactions-fraud-datasets). The data came in a very messy state with mixed datatypes,inconsistent characters and missing values. Using **Python**...I

- Converted JSON label files into structured DataFrames.

- Changed datatypes (e.g., dates → datetime, transaction amounts → numeric).

- Removed unwanted strings and reformatted categorical variables.

- Handled nulls gracefully — dropping non-informative columns and imputing where necessary.

- Ensured column naming consistency to match PostgreSQL schema.

The now cleaned dataset was then exported into **PostgreSQL** for SQL operations.
Attched [here](https://drive.google.com/drive/folders/1UIv-PtxxtwnV2Mi1n1c5PmWpAARJm4k2?usp=sharing) is the cleaned dataset.



## Database Design
The Full Database Schema can be seen [here](https://drive.google.com/file/d/1lqI41mkA1SfjnYisOZIQ_zTt5LF5tytb/view?usp=sharing)

The database schema includes five main tables:  
- **users** – information about customers.  
- **cards** – card details of customers.  
- **merchants** – merchant profiles.  
- **transactions** – ~13M rows of financial transactions.  
- **fraud_labels** – indicates fraudulent vs non-fraudulent activity. 

For full table creation scripts...see [here](./Sql_scripts/create_table_script.sql).



## Database Optimization

Given that the *transactions* table has 13M+ rows, naive queries would be slow. So i engineered the database for scale:

### Indexes
- Added indexes to transaction_date, card_id, client_id, merchant_id and columns that are frequently queries

- Ensured query filters and joins hit indexed columns.

- Result: Queries that previously scanned millions of rows      dropped to millisecond responses.

Ran the following query to check the execution time
```sql
explain analyze
select * from transactions where card_id = 1807;
```

Explain Analyze before Indexing

![image](./Screenshots/Query%20before%20optimization.png)


Explain Analyze after Indexing

![image](./Screenshots/Query%20after%20optimization.png)




### Partitioning
- The transactions table was range-partitioned by year on transaction_date and indexed.

- Advantage: queries restricted to specific years only scan relevant partitions, reducing I/O dramatically.

- Added a default “future” partition to capture incoming data.

Validated that partition works by inserting a new row below

```sql

insert into financial_system.transactions
(transaction_id, transaction_date, client_id, card_id, amount, use_chip, merchant_city, merchant_state)
values (999999, '2015-06-01', 123, 456, 200.0, 'Y', 'Lagos', 'NG');
```

Checking the partition it falls below

```sql
select tableoid::regclass as partition_name,*
from financial_system.transactions
where transaction_id = 999999;
```

Result:

![image](./Screenshots/Partition%20verification%20result.png)


Indexed the partitioned table

```sql
do $$
declare
    part RECORD;
begin
    for part in
        select inhrelid::regclass as partition_name
        from pg_inherits
        where inhparent = 'financial_system.transactions'::regclass
    loop
        execute format('
            create index if not exists %I_transaction_date_idx ON %s (transaction_date);
            create index if not exists %I_client_id_idx ON %s (client_id);
            create index if not exists %I_card_id_idx ON %s (card_id);
            create index if not exists %I_merchant_city_idx ON %s (merchant_city);
            create index if not exists %I_merchant_state_idx ON %s (merchant_state);
        ',
            part.partition_name, part.partition_name,
            part.partition_name, part.partition_name,
            part.partition_name, part.partition_name,
            part.partition_name, part.partition_name,
            part.partition_name, part.partition_name
        );
    end loop;
end$$;

```


Validating the performance of the transaction table using this query below:

```sql
explain analyze
select * from transactions
where transaction_date between '2014-01-01' and '2014-07-20';
```

Results show SQL ONLY scanned transaction table of year 2014

![image](./Screenshots/explain%20analyze2.png)




### Materialized Views
- Built client_yearly_spending as a materialized view for quick reporting.

- Aggregates millions of rows into precomputed yearly totals and averages per client.

- Refreshable with a single command:
```sql
refresh materialized view client_yearly_spending;
```



The Full scripts can be seen [here](./Sql_scripts/optimization_script.sql)






## Stored Procedures, Views and Triggers (Automation and Intergrity)

### Stored Procedures

Designed for reusablilty and automation:

- **Monthly Spend per User**: quickly retrieves a breakdown of spending per user across months.

- **Profile Summary**: compiles user details, card limits, and aggregated transactions into a single report.

- **Card Usage Statistics**: shows transaction counts and amounts per card, useful for both analytics and fraud detection.


Example of stored procedures created

*Monthly spending summary per user*

```sql
create or replace procedure get_monthly_summary(p_user_id int)
language plpgsql
as $$
declare
rec record; -- declare variable
begin
	for rec in 
		select date_trunc('month',t.transaction_date) as month,sum(t.amount) as total_spent
		from transactions t where t.client_id = p_user_id
		group by 1
		order by 1	
	loop
		raise notice 'Month: %,Total spent: %',rec.month,rec.total_spent;
	end loop;
end;
$$;
```

Calling the stored procedure below

```sql
call get_monthly_summary(825);
```


### Triggers

Used to perform an action whenever an event happens: 

- **Fraud Detection Trigger**: whenever a new fraud label is inserted with “Yes,” the system automatically logs it in fraud_alert.

- Ensures real-time fraud flagging.

- **Credit Limit Trigger**: blocks any new transaction that would exceed a card’s limit.

Enforces business rules at the database level, ensuring no inconsistent or invalid financial activity is recorded.


Example trigger created

```sql
create or replace function raise_fraud_alert()
returns trigger as $$
begin
if new.fraud_label = 'Yes' then
insert into fraud_alert(transaction_id,alert_message)
values(new.transaction_id,'Fraudulent Transaction Detected');
end if;
return new;
end;
$$ language plpgsql;
```

Validating that the trigger works by adding in a new fraudulent transaction 

```sql
insert into fraud_labels(transaction_id,fraud_label)
values(419,'Yes');
```

Result can be seen below

![image](./Screenshots/After%20fraud%20label%20detected.png)





### Views

Views make it easier for analysts to get summaries without repeating SQL

- Fast access to all fraud-flagged events with key join context

- Surfaces high-value activity instantly for finance, ops, and risk

- Quick look at top customer segments by income for premium services or product strategy


Example of view created

```sql
create or replace view fraud_transactions as
select f.transaction_id,t.transaction_date,t.amount,t.card_id,u.id,u.address
from fraud_labels f join transactions t
on f.transaction_id = t.transaction_id
join users u
on t.client_id = u.id
where fraud_label = 'Yes';
```

Calling the view
```sql
select * from fraud_transactions;
```

All SQL scripts for this lives [here](./Sql_scripts/stored%20procedures,%20triggers%20and%20views%20script.sql)







## Reporting & Analytics

To make the dataset actionable, several queries and views were written:  

- **Monthly transaction volume** (trend analysis). 

```sql
select extract('month' from transaction_date) as Month_number,to_char(transaction_date,'month') as Monthname,sum(amount)
from transactions t
group by Month_number,Monthname
order by Month_number;
```

- **Fraudulent vs non-fraudulent transaction rates**.  

```sql
select Fraudulent,Non_fraudulent,(Fraudulent::decimal/nullif(Non_fraudulent,0)) * 100 as Percentage
from
(select
count(case when fraud_label = 'Yes' then 1 end) as Fraudulent,
count(case when fraud_label = 'No' then 1 end) as Non_fraudulent
from fraud_labels);
```

- **Top fraud-prone merchant locations**. 

```sql
select t.merchant_city,t.merchant_state,count(*) as Fraudulent_transactions
from transactions t join fraud_labels f
on t.transaction_id = f.transaction_id
where f.fraud_label = 'Yes'
group by t.merchant_city,t.merchant_state
order by Fraudulent_transactions desc;
```






## How to Run
1. Clone the repository:  
   ```bash
   git clone https://github.com/NStanley0524/financial-sql-project.git
   cd financial-sql-project
   ```
2. Ensure PostgreSQL 12+ is installed and running.

3. Create a database schema in pgAdmin (e.g., financial_system).

4. Run scripts in this order:

        - 01_create_tables.sql

        - 02_optimization.sql

        - 03_procedures_triggers_views.sql

        - 04_reporting_analytics.sql

5. Load the cleaned dataset into the base tables.

6. Refresh materialized views when needed:

```sql
refresh materialzed view client_yearly_spending;
```




