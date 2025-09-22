# Financial_Database_Management_SQL
This repository contains a complete end-to-end SQL project built on a large financial transactions dataset. The project demonstrates advanced SQL database engineering concepts such as partitioning, indexing, stored procedures, triggers, materialized views, and business-focused reporting.


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
The database schema includes five main tables:  
- **users** – information about customers.  
- **cards** – card details of customers.  
- **merchants** – merchant profiles.  
- **transactions** – ~13M rows of financial transactions.  
- **fraud_labels** – indicates fraudulent vs non-fraudulent activity. 

For full table creation scripts...see [here](./Sql_scripts/create_table_script.sql).



## Database Optimization

Given that the *transactions* table has 13M+ rows, naive queries would be slow. So i engineered the database for scale:

1. **Indexes**
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




2. **Partitioning**
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




3. **Materialized Views**
- Built client_yearly_spending as a materialized view for quick reporting.

- Aggregates millions of rows into precomputed yearly totals and averages per client.

- Refreshable with a single command:
```sql
refresh materialized view client_yearly_spending;
```



## Stored Procedures, Views and Triggers (Automation and Intergrity)

### Stored Procedures

Designed for reusablilty and automation:

- Monthly Spend per User: quickly retrieves a breakdown of spending per user across months.

- Profile Summary: compiles user details, card limits, and aggregated transactions into a single report.

- Card Usage Statistics: shows transaction counts and amounts per card, useful for both analytics and fraud detection.

