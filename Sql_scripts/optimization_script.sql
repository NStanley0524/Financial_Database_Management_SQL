set search_path to financial_system,public


select * from users;
select * from cards;
select * from transactions;
select * from merchants;
select * from fraud_labels;



-- running query to make sure all joins are good

select c.id,c.gender,c.address,ca.card_number,ca.card_type
from users c join cards ca
on c.id = ca.user_id;




-- Optimization

explain analyze
select * from transactions where card_id = 1807;

create index idx_transactions_card_id
on transactions(card_id);


explain analyze
select * from transactions where card_id = 1807;




-- INDEX ON TRANSACTIONS TABLE

create index idx_transactions_client_id
on transactions(client_id);

create index idx_transactions_merchant_id
on transactions(merchant_id);

create index idx_transactions_amount
on transactions(amount);

create index idx_transactions_trans_id
on transactions(transaction_id);

create index idx_transaction_date
on transactions(transaction_date);

-- INDEX ON USERS TABLE

create index idx_users_id
on users(id);

create index idx_users_yearly_income
on users(yearly_income);



-- INDEX ON CARDS

create index idx_cards_user_id
on cards(user_id);



-- INDEX ON FRAUD LABELS

create index idx_fraud_labels_trans_id
on fraud_labels(transaction_id);




-- PARTITIONING MY TRANSACTION TABLE

alter table transactions rename to transactions_old;


create table financial_system.transactions(
transaction_id int,
transaction_date date not null,
client_id int references financial_system.users(id),
card_id int references financial_system.cards(id),
amount float,
use_chip varchar(200),
merchant_id int,
merchant_city varchar(200),
merchant_state varchar(50),
zip varchar(200),
mcc int
)partition by range(transaction_date);



-- CREATING PARTITIONS

create table financial_system.transactions_2010
partition of financial_system.transactions
for values from ('2010-01-01') to ('2011-01-01');

alter table financial_system.transactions_2010
add constraint transactions_2010_pkey primary key(transaction_id);


create table financial_system.transactions_2011
partition of financial_system.transactions
for values from ('2011-01-01') to ('2012-01-01');

alter table financial_system.transactions_2011
add constraint transactions_2011_pkey primary key(transaction_id);


create table financial_system.transactions_2012
partition of financial_system.transactions
for values from ('2012-01-01') to ('2013-01-01');

alter table financial_system.transactions_2012
add constraint transactions_2012_pkey primary key(transaction_id);

create table financial_system.transactions_2013
partition of financial_system.transactions
for values from ('2013-01-01') to ('2014-01-01');

alter table financial_system.transactions_2013
add constraint transactions_2013_pkey primary key(transaction_id);

create table financial_system.transactions_2014
partition of financial_system.transactions
for values from ('2014-01-01') to ('2015-01-01');

alter table financial_system.transactions_2014
add constraint transactions_2014_pkey primary key(transaction_id);

create table financial_system.transactions_2015
partition of financial_system.transactions
for values from ('2015-01-01') to ('2016-01-01');

alter table financial_system.transactions_2015
add constraint transactions_2015_pkey primary key(transaction_id);

create table financial_system.transactions_2016
partition of financial_system.transactions
for values from ('2016-01-01') to ('2017-01-01');

alter table financial_system.transactions_2016
add constraint transactions_2016_pkey primary key(transaction_id);

create table financial_system.transactions_2017
partition of financial_system.transactions
for values from ('2017-01-01') to ('2018-01-01');

alter table financial_system.transactions_2017
add constraint transactions_2017_pkey primary key(transaction_id);

create table financial_system.transactions_2018
partition of financial_system.transactions
for values from ('2018-01-01') to ('2019-01-01');

alter table financial_system.transactions_2018
add constraint transactions_2018_pkey primary key(transaction_id);

create table financial_system.transactions_2019
partition of financial_system.transactions
for values from ('2019-01-01') to ('2020-01-01');

alter table financial_system.transactions_2019
add constraint transactions_2019_pkey primary key(transaction_id);


-- For future transactions

create table financial_system.transactions_future
partition of financial_system.transactions
for values from ('2020-01-01') to (maxvalue);

alter table financial_system.transactions_future
add constraint transactions_future_pkey primary key(transaction_id);

create index idx_transactions_future
on transactions_future(transaction_id);




-- INSERTING THE TABLES FROM THE OLD TO THE NEW

insert into financial_system.transactions
select * from financial_system.transactions_old;


-- VALIDATING THAT PARTITION WORKS

insert into financial_system.transactions
(transaction_id, transaction_date, client_id, card_id, amount, use_chip, merchant_city, merchant_state)
values (999999, '2015-06-01', 123, 456, 200.0, 'Y', 'Lagos', 'NG');


-- checking which partition it falls

select tableoid::regclass as partition_name,*
from financial_system.transactions
where transaction_id = 999999;



-- INDEXING THE PARTITIONED TABLE

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




-- TESTING THE PERFORMANCE OF TRANSACTIONS TABLE

explain analyze
select * from transactions;


explain analyze
select * from transactions
where transaction_date between '2014-01-01' and '2014-07-20';





-- MATERIALIZED VIEW FOR REPORTING

create materialized view financial_system.client_yearly_spending as
select client_id,extract(year from transaction_date) as year,count(*) as total_transaction,sum(amount) as amount,avg(amount) as average_transaction
from financial_system.transactions
group by client_id,extract(year from transaction_date);


-- testing

select * from client_yearly_spending



-- DROPPING OLD TABLE

alter table fraud_labels
drop constraint fraud_labels_transaction_id_fkey;


drop table transactions_old;