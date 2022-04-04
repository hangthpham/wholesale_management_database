drop procedure if exists new_order;
drop procedure if exists order_items;
drop trigger if exists before_insert_order; 
drop trigger if exists ordered_quantity_check ;
drop trigger if exists before_item_input;
drop trigger if exists update_order_status;
drop trigger if exists update_order_items;
drop trigger if exists before_update_customer_credit;
delimiter //

-- ADD NEW ORDER
CREATE PROCEDURE new_order (IN order_id int, c_id int, sales_agent_id int, order_date timestamp,
			    status enum('quote','processing','shipped/picked up'), 
                            p_id int, quantity int, Discount decimal(10,2),
                            instore_credit decimal(10,2), customer_credit_used decimal(10,2))
BEGIN 
declare applied_sales_price	decimal(10,2);
declare total_before_tax decimal(10,2);
declare shipping_date date;
declare credit_term varchar(50);
-- Roll back if any query inside the procedure fails
declare errno int;
declare Exit Handler for sqlexception
Begin 
get current diagnostics condition 1 errno = mysql_errno;
select errno as mySQL_error;
rollback;
resignal;
end;

set applied_sales_price = (select sales_price from product where product_id = p_id);
set total_before_tax = applied_sales_price*quantity - discount;
set credit_term = (select customer_credit_term from customer where customer_id = c_id);
START TRANSACTION;  
-- Settings for same day pick up/delivery orders
if status = 'shipped/picked up' then 
		set shipping_date = date(order_date);
		update inventory 
		set total_quantity = total_quantity - quantity
		where product_id = p_id;
	elseif status = 'processing' then
		update inventory 
		set reserved = reserved + quantity
		where product_id = p_id;
	else set shipping_date = null; 
	end if; 
  
insert into orders (order_id, order_date, status, shipped_date, customer_id, sales_agent_id,
					total_before_tax, discount, instore_credit, customer_credit_used)
	values (order_id, order_date, status, shipping_date, c_id, sales_agent_id,
			total_before_tax, discount, instore_credit, customer_credit_used);
insert into orderdetails (order_id, product_id, quantity, sales_price)
	values (order_id, p_id, quantity, applied_sales_price);
-- In case any credit is used, reflect changes in InStore_credit and customer_credit_used from Customer table
if instore_credit > 0 and status != 'quote' then
	update customer c 
    set c.instore_credit = c.instore_credit - instore_credit
	where c.customer_id = c_id;
    end if;
if customer_credit_used > 0 and status != 'quote' then
	update customer c
    set c.used_credit = c.used_credit + customer_credit_used
    where c.customer_id = c_id;
-- For customer_credit_used, update Accounts Receivable accordingly
    insert into Accounts_receivable (customer_id, salesrep_id, order_id, order_date, 
									customer_credit_used, customer_credit_term)
	values (c_id, sales_agent_id, order_id, order_date, customer_credit_used, credit_term);
    end if;
Commit;
end //

-- Check for requirements before inserting a new order
CREATE TRIGGER before_insert_order
before insert on Orders for each row 
begin 
declare available_inStore_credit decimal(10,2) default 0;
declare available_credit decimal (10,2);	
set available_inStore_credit = (select inStore_credit from customer where customer_id = new.customer_id);
set available_credit = (select remaining_credit_limit from customer where customer_id = new.customer_id);
set @message_text1 = Concat('Applied inStore_credit must not exceed available inStore_credit - ',available_inStore_credit);
set @message_text2 = concat('Applied customer_credit must not exceed available customer_credit - ',available_credit);
set @message_text3 = concat('Applied discount must not exceed total amount before tax - ',(new.total_before_tax + new.discount));
set @message_text4 = concat('Applied in-store credit must not exceed total amount - ',(new.total_before_tax + new.tax));
set @message_text5 = concat('Applied customer credits must not exceed total amount - ',new.total); 

-- Check for duplicate order using order id
	if (exists (select 1 from Orders 
    where order_id = new.order_id)) then
	signal SQLSTATE VALUE '45000' set message_text = 'Insert failed due to duplicate order id';
    end if;
-- Check if any applied credits are more than available credits
if new.instore_credit > available_instore_credit then
	signal SQLSTATE Value '45000' set message_text = @message_text1;
	end if;
if new.customer_credit_used > available_credit then
	signal SQLSTATE '45000' set message_text = @message_text2;
	end if; 
-- check if any applied discount more than total order amount before tax
if (new.total_before_tax + new.discount) < new.discount then
    signal SQLSTATE '45000' set message_text = @message_text3;
	-- or any applied in-store credit more than total order amount
    elseif (new.total_before_tax + new.tax) < new.inStore_credit then
	signal SQLSTATE '45000' set message_text = @message_text4;
	-- or any applied customer credit more than final total order amount after applying any in-store credit
    elseif new.total < new.customer_credit_used then
	signal SQLSTATE '45000' set message_text = @message_text5;
    end if;
end //

/* Check if - ordered quantity is more than available quantity in stock 
	    - one specific item for the order already exists (duplicate order item for each order) */
CREATE TRIGGER ordered_quantity_check 
before insert on orderdetails for each row
BEGIN 
declare available_quantity int;
set available_quantity = (select available from inventory where product_id = new.product_id);
set @message_text1 = concat('Ordered quantity must not exceed available quantity in stock - ', available_quantity);
if new.quantity > available_quantity then
	signal SQLSTATE value '45000' set message_text = @message_text1; 
    end if;
-- check for duplicate order item
if exists(select 1 from orderdetails 
			where (order_id,product_id) = (new.order_id, new.product_id)) then
	signal SQLSTATE '45000' set message_text = 'Insert failed due to duplicate item for this order id';
    end if;
end//

-- To add additional items when customer buy more than 1 item for their order
CREATE PROCEDURE Order_items (IN o_id int, p_id int, quantity int)
BEGIN
declare applied_sales_price	decimal(10,2);
declare total_per_item decimal(10,2);
declare order_status enum('quote','processing','shipped/picked up');
set applied_sales_price = (select sales_price from product where product_id = p_id);
set total_per_item = applied_sales_price * quantity;
set order_status = (select status from orders where order_id = o_id);

insert into orderdetails (order_id, product_id, quantity, sales_price)
	values (o_id, p_id, quantity, applied_sales_price);
-- automatically re-calculate and update total order amount in Orders table
update orders 
	set orders.total_before_tax = orders.total_before_tax + total_per_item
	where orders.order_id = o_id;
-- update inventory accordingly
if order_status = 'processing'
	then update inventory 
	set reserved = reserved + quantity
	where product_id = p_id;
	elseif order_status = 'shipped/picked up'
    then update inventory 
    set total_quantity = total_quantity - quantity
    where product_id = p_id;
    end if;
end//

-- Automatically update Inventory, Customer credits (in store and customer credit), Accounts receivable (if any) whenever the Order Status is updated 
CREATE TRIGGER update_order_status 
after update on Orders for each row 
begin  
declare credit_term varchar(50);
declare updated_order_date timestamp;
set credit_term = (select customer_credit_term from customer where customer_id = new.customer_id);
set updated_order_date = current_timestamp();

if new.status = 'processing' and old.status = 'quote' then
    update inventory i
    join orderdetails od join orders o 
    on i.product_id = od.product_id and o.order_id = od.order_id
    set i.reserved = i.reserved + od.quantity 
    where od.order_id = new.order_id;
    update customer c
    join orders o on c.customer_id = o.customer_id
    set c.used_credit = c.used_credit + o.customer_credit_used,
    c.instore_credit = c.instore_credit - o.instore_credit
    where o.order_id = new.order_id;
	if new.customer_credit_used > 0 then
		insert into accounts_receivable (Order_ID, customer_id, salesrep_id,order_date, customer_credit_used,customer_credit_term)
		values (new.order_id,new.customer_id,new.sales_agent_id,updated_order_date, new.customer_credit_used, credit_term);
		end if;
        
    elseif new.status = 'shipped/picked up' and old.status = 'processing' then
    update inventory i
    join orderdetails od join orders o 
    on i.product_id = od.product_id and o.order_id = od.order_id
    set i.reserved = i.reserved - od.quantity,
    i.total_quantity = i.total_quantity - od.quantity
    where od.order_id = new.order_id;
    if new.shipped_date is null then 
		signal SQLSTATE '45000' set message_text = 'Shipped_date cannot be null. Please insert shipped_date.';
        end if;
    
    elseif new.status = 'cancelled' and old.status = 'processing' then
    update inventory i
    join orderdetails od join orders o 
    on i.product_id = od.product_id and o.order_id = od.order_id
    set i.reserved = i.reserved - od.quantity
    where od.order_id = new.order_id;
    update customer c
    join orders o on c.customer_id = o.customer_id
    set c.used_credit = c.used_credit - o.customer_credit_used,
    c.instore_credit = c.instore_credit + o.instore_credit
    where o.order_id = new.order_id;
    delete ar
    from accounts_receivable ar join orders o on ar.order_id = o.order_id
    where o.order_id = new.order_id;
    
    elseif new.status = 'cancelled' and old.status = 'shipped/picked up' then 
	signal SQLSTATE '45000' set message_text = 'This order is already shipped/picked up. You cannot cancel it'; 
	end if;
end//

-- Orders can only be updated and take effects when its status is 'processing'. Use trigger to enforce this condition.  
CREATE TRIGGER update_order_items 
after update on OrderDetails for each row 
begin
declare order_status enum('quote','processing','shipped/picked up','cancelled');
set order_status = (select distinct o.status from orders o join orderdetails od on o.order_id = od.order_id where o.order_id = new.order_id); 

if order_status = 'shipped/picked up' then
	signal SQLSTATE '45000' set message_text = 'This order is already shipped/picked up. You cannot change the order items!';
    elseif order_status = 'processing' then 
    update inventory i
    join orderdetails od join orders o 
    on i.product_id = od.product_id and o.order_id = od.order_id
    set i.reserved = i.reserved - old.quantity + new.quantity
    where od.order_id = new.order_id;
    end if;
end //

-- To make sure that all types of credits used for the order will be less than the customer's available credits (in store credit and remaining credit limit)
CREATE TRIGGER before_update_customer_credit
before update on customer for each row 
begin
	if new.instore_credit < 0 or new.remaining_credit_limit < 0 then
    signal SQLSTATE '45000' set message_text = 'Insufficent credits for this update. It would result in negative credits';
    end if;
end //


        
				


    

 
