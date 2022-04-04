delimiter //
-- ADD NEW EMPLOYEE
CREATE PROCEDURE new_emp (IN employee_id int,
						first_name varchar(50), last_name varchar(50),
						phone_number bigint, email varchar(100),
						job_title varchar(50), department varchar(50),
                        managerID int, salary int, 
                        street_address varchar(255), city varchar(50), 
                        state varchar(50), zip_code int(10),
                        employment_date date)
begin 
SET max_sp_recursion_depth=255;
insert into employee 
values (employee_id, first_name, last_name, phone_number, email, job_title, 
	department, managerID, salary, street_address, city, state, zip_code, Employment_date);
end//
-- Check for duplicate employee via employee_id or phone_number
CREATE TRIGGER before_insert_emp
before insert on Employee for each row 
begin 
	if (exists (select 1 from employee 
	where phone_number = new.phone_number or employee_id = new.employee_id)) then
	signal SQLSTATE VALUE '45000' set message_text = 'Insert failed due to duplicate phone number or employee id';
	end if;
end//
-- ADD NEW CUSTOMER
CREATE PROCEDURE new_customer (IN customer_id int,
									customer_name varchar(100), contact_name varchar(100),
                                    phone_number bigint, email varchar(100),
                                    status enum('active','inactive'),
                                    street_address varchar(255),city varchar(50),state varchar(50), zip_code int(10), 
                                    customer_credit_limit decimal(10,2), used_credit decimal(10,2),
                                    customer_credit_term varchar(50), 
                                    inStore_credit decimal(10,2),salesRep_id int)
begin 
insert into customer (customer_id, customer_name, contact_name, phone_number, email, status,
		street_address,city,state, zip_code, 
		customer_credit_limit, used_credit, 
		customer_credit_term, inStore_credit, salesRep_id)
values (customer_id, customer_name, contact_name, phone_number, email, status,
		street_address,city,state, zip_code, 
		customer_credit_limit, used_credit, 
		customer_credit_term, inStore_credit, salesRep_id);
end//
-- Check for duplicate customer via customer_id or phone_number
CREATE TRIGGER before_insert_customer
before insert on Customer for each row 
begin 
	if (exists (select 1 from customer 
	where phone_number = new.phone_number or customer_id = new.customer_id)) then
	signal SQLSTATE VALUE '45000' set message_text = 'Insert failed due to duplicate phone number or customer id';
	end if;
end//
-- ADD NEW SUPPLIER
CREATE PROCEDURE new_supplier (IN supplier_id int,company_name varchar(100), contact_name varchar(100),
								phone_number bigint, email varchar(100), status	enum('active','inactive'),
                                street_address varchar(255), city varchar(50), state varchar(50),
                                zip_code int, country varchar(50), shipping_days int, supplier_credit_limit decimal(10,2),
                                used_credit	decimal(10,2), supplier_credit_term varchar(50), agent_id int)
begin 
insert into supplier (supplier_id, company_name, contact_name, phone_number, email, status,
		street_address,city,state, zip_code, country, shipping_days,
		supplier_credit_limit, used_credit, supplier_credit_term, agent_id)
values (supplier_id, company_name, contact_name, phone_number, email, status,
		street_address,city,state, zip_code, country, shipping_days,
		supplier_credit_limit, used_credit, supplier_credit_term, agent_id);
end//
-- Check for duplicate supplier via supplier_id or phone_number
CREATE TRIGGER before_insert_supplier
before insert on supplier for each row 
begin 
	if (exists (select 1 from supplier 
	where phone_number = new.phone_number or supplier_id = new.supplier_id)) then
	signal SQLSTATE VALUE '45000' set message_text = 'Insert failed due to duplicate phone number or supplier id';
	end if;
end//
-- ADD NEW PRODUCT / INVENTORY AT THE SAME TIME
CREATE PROCEDURE new_product_inventory (IN product_id	int, product_name varchar(100), category varchar(50),
							description	varchar(255),status	enum('continued','discontinued'), quantity int,
                            purchase_price decimal(10,2), sales_price decimal(10,2), supplier_id int)
BEGIN 
Insert into Product (product_id, product_name, category,description,
					status, purchase_price, sales_price, supplier_id)
	values (product_id, product_name, category,description,
					status, purchase_price, sales_price, supplier_id);
-- Update Inventory table
Insert into Inventory (product_id, product_name, total_quantity, supplier_id) 
	values (product_id, product_name, quantity, supplier_id);
End//
-- Check for duplicate product via product_id or (supplier_ID, product_name)
CREATE TRIGGER before_insert_product
before insert on Product for each row 
begin 
	if (exists (select 1 from product 
	where product_id = new.product_id or (supplier_id, product_name) = (new.supplier_id,new.product_name))) then
	signal SQLSTATE VALUE '45000' set message_text = 'Insert failed due to duplicate product id or product name from one supplier';
    end if;
end//                 


 

