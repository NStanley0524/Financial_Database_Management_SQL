create table financial_system.users(
id int primary key,
current_age int,
retirement_age int,
birth_year int,
birth_month int,
gender varchar(200),
address varchar(200),
latitude int,
longitude int,
per_capita_income int,
yearly_income int,
total_debt int,
credit_score int,
num_credit_cards int
);



create table financial_system.cards(
id int primary key,
user_id int references financial_system.users(id),
card_brand varchar(200),
card_type varchar(200),
card_number int unique not null,
expires date,
cvv int,
has_chip varchar(200),
num_cards_issued int,
credit_limit int,
acct_open_date date,
year_pin_last_changed int,
card_on_dark_web varchar(50)
);





create table financial_system.merchants(
merchant_id int primary key,
description text
);





create table financial_system.transactions(
transaction_id int primary key,
transaction_date date,
client_id int references financial_system.users(id),
card_id int references financial_system.cards(id),
amount float,
use_chip varchar(200),
merchant_id int references financial_system.merchants(merchant_id),
merchant_city varchar(200),
merchant_state varchar(50),
zip varchar(200),
mcc int
);





create table financial_system.fraud_labels(
transaction_id int references financial_system.transactions(transaction_id),
fraud_label varchar(50)
);


