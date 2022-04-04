drop database if exists wholesale_management_system;
create database wholesale_management_system;
use wholesale_management_system;

-- EMPLOYEE TABLE 
CREATE TABLE Employee (
employee_id int auto_increment primary key,
first_name varchar(50) not null,
last_name varchar(50) not null,
phone_number bigint unique not null,
email varchar(100) not null,
job_title varchar(50) not null,
department varchar(50),
managerID int default null,
salary int,
street_address varchar(255) not null,
city varchar(50) not null,
state varchar(50) not null, 
zip_code int(10), 
Employment_date date default (current_date),
constraint FK_emp_manager foreign key (managerid) 
	references employee (employee_id)
	on update cascade on delete set null
);

-- SUPPLIER TABLE 
CREATE TABLE Supplier ( 
supplier_id int auto_increment primary key,
company_name varchar(100) not null,
contact_name varchar(100) not null,
phone_number bigint unique not null,
email varchar(100) not null,
status enum('active','inactive') not null,
street_address varchar(255) not null,
city varchar(50) not null,
state varchar(50) not null, 
zip_code int(10), 
country varchar(50) not null,
shipping_days int not null,
supplier_credit_limit decimal(10,2) default 0,
used_credit decimal(10,2) default 0,
remaining_credit_limit decimal(10,2) generated always as (supplier_credit_limit - used_credit),
supplier_credit_term varchar(50),
agent_id int,	-- the one who works directly with the supplier
constraint FK_supplier_emp foreign key (agent_id) 
references employee (employee_id)
on update cascade on delete set null
);

-- CUSTOMER TABLE
CREATE TABLE Customer (
customer_id int auto_increment primary key,
customer_name varchar(100) not null,
contact_name varchar(100) not null,
phone_number bigint unique not null,
email varchar(100) not null,
status enum('active','inactive') not null,
street_address varchar(255) not null,
city varchar(50) not null,
state varchar(50) not null, 
zip_code int(10), 
customer_credit_limit decimal(10,2) default 0,
used_credit decimal(10,2) default 0,
remaining_credit_limit decimal(10,2) generated always as (customer_credit_limit - used_credit),
customer_credit_term varchar(50),
inStore_credit decimal(10,2),
salesRep_id int,	-- the one who works directly with the customer
constraint FK_customer_emp foreign key (salesrep_id) 
references employee (employee_id)
on update cascade on delete set null
);

-- PRODUCT TABLE
CREATE TABLE Product (
product_id int auto_increment primary key,
product_name varchar(100) not null,
category varchar(50),
description varchar(255),
status enum('continued','discontinued'),
purchase_price decimal(10,2),
sales_price decimal(10,2),
supplier_id int not null, 
constraint FK_product_supplier foreign key (supplier_id)
references supplier(supplier_id)
on update cascade 
);

-- INVENTORY TABLE 
CREATE TABLE Inventory (
Product_ID int auto_increment primary key,
product_name varchar(100) not null,
total_quantity int default 0,
reserved int default 0,
available int generated always as (total_quantity - reserved),
quantity_PO int default 0,
PO_IDs varchar(100), 
supplier_ID int not null, 
safety_stock_level int default 0,
reorder_point int default 0,
constraint FK_Inv_product foreign key (product_id)
references product(product_id)
on update cascade,
constraint FK_Inv_supplier foreign key (supplier_id)
references supplier(supplier_id)
on update cascade 
);

--  ORDER TABLE
CREATE TABLE Orders (
Order_id int auto_increment primary key,
customer_id int,
sales_agent_id int,
order_date timestamp default current_timestamp,
status enum('quote','processing','shipped/picked up','cancelled'),
shipped_date date,
Discount decimal(10,2),
total_before_tax decimal(10,2) not null,
tax decimal(10,2) generated always as (0.06*total_before_tax),
instore_credit decimal(10,2),
total decimal(10,2) generated always as (total_before_tax + tax - instore_credit),
customer_credit_used decimal(10,2),
Paid_amount decimal(10,2) generated always as (total - customer_credit_used),
constraint FK_Orders_customer foreign key (customer_id)
references customer(customer_id)
on update cascade,
constraint FK_Orders_emp foreign key (sales_agent_id)
references employee(employee_id)
on update cascade on delete set null
);

-- ORDER DETAILS TABLE
CREATE TABLE OrderDetails (
Order_id int not null,
product_id int not null,
quantity int(50) not null,
sales_price decimal(10,2) not null,
primary key (order_id,product_id),
constraint FK_OrderDetail_order foreign key (order_id)
references orders (order_id)
on update cascade on delete cascade,
constraint FK_OrderDetail_product foreign key (product_id)
references product (product_id) 
on update cascade
);

-- PURCHASING_ORDER TABLE
CREATE TABLE Purchasing_order (
PO_id int auto_increment primary key,
supplier_id int,
Agent_id int,
purchase_date timestamp default current_timestamp ,
status enum('processing','shipped','delivered','cancelled'),
shipped_date date,
estimate_arrival_time date,
received_date date,
Discount decimal(10,2),
total_before_tax decimal(10,2),
tax_including_duty decimal(10,2),
total decimal(10,2) generated always as (total_before_tax + tax_including_duty),
supplier_credit_used decimal(10,2),
Paid_amount decimal(10,2) generated always as (total - supplier_credit_used),
constraint FK_PO_supplier foreign key (supplier_id)
references supplier(supplier_id)
on update cascade,
constraint FK_PO_emp foreign key (agent_id)
references employee(employee_id)
on update cascade on delete set null
);

-- PO_DETAILS TABLE 
CREATE TABLE PO_details (
PO_id int not null, 
product_id int,
purchase_price decimal(10,2) not null,
quantity int(50) not null,
primary key (PO_id,product_id),
constraint FK_POD_POid foreign key (PO_id)
references purchasing_order (PO_id)
on update cascade on delete cascade,
constraint FK_POD_product foreign key (product_id)
references product (product_id)
on update cascade on delete set null
);

-- ACCOUNTS_PAYABLE TABLE
CREATE TABLE accounts_payable (
PO_ID int primary key,
supplier_id int not null,
agent_id int not null,
purchase_date timestamp,
supplier_credit_used decimal(10,2),
supplier_credit_term varchar(50),
due_date timestamp generated always as (timestampadd(day,supplier_credit_term,purchase_date)),
payment_date date,
check_no varchar(50)
); 

-- ACCOUNTS_RECEIVABLE TABLE 
CREATE TABLE accounts_receivable (
Order_ID int primary key,
customer_id int not null,
salesrep_id int not null,
order_date timestamp not null,
customer_credit_used decimal(10,2),
customer_credit_term varchar(50),
due_date timestamp generated always as (timestampadd(day,customer_credit_term,order_date)),
payment_date date,
check_no varchar(50)
); 
