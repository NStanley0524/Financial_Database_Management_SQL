set search_path to financial_system,public;

 
-- STORED PROCEDURES

/*Stored procedures are used for Re-usable business logic...when we want a repeatable logic like reporting, fraud detection or aggregrations

The following stored procedures will be created 
*/

-- 1. Monthly spending summary per user

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



-- Calling the procedure to get monthly summary of user 825

call get_monthly_summary(825);



-- 2. Get Profile Summary

create or replace procedure get_profile_summary(p_user_id int)
language plpgsql
as $$
declare
rec record; -- declaring variable
begin
	select u.id,u.gender,u.address,count(t.transaction_id) as total_transactions,sum(t.amount) as total_amount
	into rec
	from users u join transactions t
	on u.id = t.client_id
	where u.id = p_user_id
	group by u.id,u.gender,u.address;

	raise notice 'User ID: %, Gender: %, Address: %, Total Transactions: %, Total Amount: %',rec.id,rec.gender,rec.address,rec.total_transactions,rec.total_amount;
end;
$$;



-- calling the procedure to get profile summary of user 1164

call get_profile_summary(1164);





-- 3. Get card usage stats

create or replace procedure get_card_usage_stats(p_card_id int)
language plpgsql
as $$
declare
rec record; --declaring variable
begin
	select c.card_type,c.expires,c.credit_limit,count(t.transaction_id) as total_transactions,sum(t.amount) as total_spent
	into rec
	from cards c join transactions t
	on c.id = t.card_id
	where c.id = p_card_id
	group by c.card_type,c.expires,c.credit_limit;

raise notice ' Card Type: %, Expiry Date: %, Credit Limit: %, Total Transactions: %, Total Spent: %',rec.card_type,rec.expires,rec.credit_limit,rec.total_transactions,rec.total_spent;
end;
$$;


-- Calling the procudure to get card information of card number 79

call get_card_usage_stats(79);







-- TRIGGERS

/*
Triggers are used to automate business logic whenever an event happens in a table

We are going to create a trigger for 3 different scenarios
*/


-- 1. Fraud Alert Trigger

-- If a transaction is flagged as fraud,automatically insert into a fraud alert table


-- create fraud_alert table

create table fraud_alert(
alert_id serial primary key,
transaction_id int references fraud_labels(transaction_id),
alert_time timestamp default now(),
alert_message text
);

-- creating trigger function

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


-- createing the trigger

create trigger fraud_label_trigger
after insert on fraud_labels
for each row
execute function raise_fraud_alert();






-- 2. Prevent Transactions more than Card Limit

-- If transaction amount is greater than the card limit, block it.

create or replace function check_credit_limit()
returns trigger as $$
declare
total_spent numeric; --total spent
card_limit numeric; --card limit
begin

-- Getting the amount spent
select coalesce(sum(amount),0)
into total_spent
from transactions
where card_id = new.card_id;

-- Getting the credit limit
select credit_limit
into card_limit
from cards
where id = new.card_id;

if (total_spent + new.amount) > card_limit then
raise exception 'Transaction declined: Exceeds credit limit(spent: %, New: %, Limit: %',total_spent,new.amount,card_limit;
end if;
return new; -- If within limit...allow transaction
end;
$$ language plpgsql;



-- creating the trigger

create trigger trg_check_credit_limit
before insert on transactions
for each row
execute function check_credit_limit();







-- CHECKING THE TRIGGERS

-- 1. 

select * from fraud_alert;

insert into fraud_labels(transaction_id,fraud_label)
values(419,'Yes');

select * from fraud_alert;


-- 2. 

select t.client_id,t.card_id,sum(t.amount),c.credit_limit
from transactions t join cards c
on t.card_id = c.id
group by t.client_id,t.card_id,c.credit_limit
order by sum(t.amount) asc;

-- client(797) with card_id 5339 has spent 120 from credit limit of 27817

-- Running the first insert of amount 20000 to show successful insert

insert into financial_system.transactions 
(transaction_id, transaction_date, client_id, card_id, amount, use_chip, merchant_id, merchant_city, merchant_state, zip, mcc)
values (1, '2025-09-21', 797, 5339, 20000, 'Y', 999, 'Lagos', 'LA', '10001', 1234);
--This was successful because transaction is within credit limit


-- checking back the balance
select t.client_id,t.card_id,sum(t.amount),c.credit_limit
from transactions t join cards c
on t.card_id = c.id
where t.client_id = 797 and card_id = 5339
group by t.client_id,t.card_id,c.credit_limit;


-- Running the secong insert of amount 10000 which would now be more than 27817 limit

insert into financial_system.transactions 
(transaction_id, transaction_date, client_id, card_id, amount, use_chip, merchant_id, merchant_city, merchant_state, zip, mcc)
values (2, '2025-09-21', 797, 5339, 10000, 'Y', 1000, 'Abuja', 'ABJ', '10002', 2468);






-- VIEWS

/* 

Views make it easier for analysts to get summaries without repeating SQL

*/


-- creating view for fraud_transactions

create or replace view fraud_transactions as
select f.transaction_id,t.transaction_date,t.amount,t.card_id,u.id,u.address
from fraud_labels f join transactions t
on f.transaction_id = t.transaction_id
join users u
on t.client_id = u.id
where fraud_label = 'Yes';

-- calling the view

select * from fraud_transactions;





-- creating view to see high value transactions

create or replace view big_transactions as
select u.id,t.transaction_id,t.transaction_date,t.amount,t.merchant_city,t.merchant_state,t.zip,m.description
from users u right join transactions t
on u.id = t.client_id
left join merchants m 
on t.merchant_id = m.merchant_id
where t.amount > 10000
order by t.amount desc;



-- calling the view

select * from big_transactions;





-- creating a view to see our wealthy customers

create or replace view wealthy_customers as
select id, gender,address,per_capita_income,yearly_income
from users
order by yearly_income desc;

-- calling the view

select * from wealthy_customers
limit 10;

