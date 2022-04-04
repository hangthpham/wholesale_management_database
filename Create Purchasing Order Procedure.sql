drop procedure if exists new_PO;
drop TRIGGER if exists before_insert_PO;
drop TRIGGER if exists before_insert_POitems;
drop procedure if exists PO_items;
drop trigger if exists update_PO_status ;
drop trigger if exists update_PO_items ;
drop trigger if exists  before_update_supplier_credit;

delimiter //
-- ADD NEW PURCHASING ORDER
CREATE PROCEDURE new_PO (PO_id int, sp_id int, Agent_id int, purchase_date timestamp,
						status enum('processing','shipped','delivered','cancelled'),
                        p_id int, quantity int, Discount decimal(10,2),tax_including_duty decimal(10,2), 
                        supplier_credit_used decimal(10,2))
BEGIN 
declare applied_purchase_price decimal(10,2);
declare total_before_tax decimal(10,2);
declare shipping_date date;
declare credit_term varchar(50);
declare ETA date;
-- Roll back if any query inside the procedure fails
declare errno int;
declare Exit Handler for sqlexception
Begin 
get current diagnostics condition 1 errno = mysql_errno;
select errno as mySQL_error;
rollback;
resignal;
end;

set applied_purchase_price = (select purchase_price from product where product_id = p_id);
set total_before_tax = applied_purchase_price*quantity - discount;
set credit_term = (select supplier_credit_term from supplier where supplier_id = sp_id);
set @shipping_days = (select shipping_days from supplier where supplier_id = sp_id);
set ETA = date_add(purchase_date,interval @shipping_days day);
START TRANSACTION;  
-- Set shipping_date for same day shipped orders
if status = 'shipped' then 
		set shipping_date = date(purchase_date);
        else set shipping_date = null; 
        end if;

if status = 'shipped' or status = 'processing' then
	update inventory 
	set PO_IDs = trim(leading ',' from (concat(ifnull(PO_IDs,''),',',PO_ID))),
	quantity_PO = quantity_PO + quantity
    where product_id = p_id;
	end if; 
  
insert into purchasing_order (PO_id, supplier_id, Agent_id, purchase_date, status,shipped_date,
                             total_before_tax, Discount, tax_including_duty, estimate_arrival_time, supplier_credit_used)
	values (PO_id, sp_id, Agent_id, purchase_date, status,shipping_date,
			total_before_tax, Discount, tax_including_duty, ETA, supplier_credit_used);
insert into PO_details (PO_id, product_id, quantity, purchase_price)
	values (PO_id, p_id, quantity, applied_purchase_price);
-- In case any supplier credit is used, reflect changes in supplier_credit_used from Supplier table
if supplier_credit_used > 0 then
	update supplier s
    set s.used_credit = s.used_credit + supplier_credit_used
    where s.supplier_id = sp_id;
-- For supplier_credit_used, update Accounts Payable accordingly
    insert into Accounts_payable (supplier_id, agent_id, PO_id, purchase_date, 
									supplier_credit_used, supplier_credit_term)
	values (sp_id, agent_id, PO_id, purchase_date, supplier_credit_used, credit_term);
    end if;
Commit;
end //

-- Check for requirements before inserting a new purchase order
CREATE TRIGGER before_insert_PO
before insert on purchasing_order for each row 
begin 
declare available_credit decimal (10,2);	
set available_credit = (select remaining_credit_limit from supplier where supplier_id = new.supplier_id);
set @message_text1 = concat('Applied supplier_credit must not exceed available supplier_credit - ',available_credit);
set @message_text2 = concat('Applied discount must not exceed total amount before tax - ',(new.total_before_tax + new.discount));
set @message_text3 = concat('Applied supplier credits must not exceed total amount - ',new.total); 

-- Check for duplicate purchase order using PO id
	if (exists (select 1 from purchasing_order 
    where PO_id = new.PO_id)) then
	signal SQLSTATE VALUE '45000' set message_text = 'Insert failed due to duplicate PO id';
    end if;
-- Check if applied supplier credits are more than available credits
if new.supplier_credit_used > available_credit then
	signal SQLSTATE '45000' set message_text = @message_text1;
	end if; 
-- check if any applied discount more than total order amount before tax
if (new.total_before_tax + new.discount) < new.discount then
    signal SQLSTATE '45000' set message_text = @message_text2;
	-- or any applied supplier credit more than total order amount 
    elseif new.total < new.supplier_credit_used then
	signal SQLSTATE '45000' set message_text = @message_text3;
    end if;
end //

-- Check if one specific item for the order already exists (duplicate order item for each order)
CREATE TRIGGER before_insert_POitems
before insert on PO_details for each row
BEGIN 
-- check for duplicate order item
if exists(select 1 from PO_details 
			where (PO_id,product_id) = (new.PO_id, new.product_id)) then
	signal SQLSTATE '45000' set message_text = 'Insert failed due to duplicate item for this PO id';
    end if;
end//

-- Used to add additional items when customer buy more than 1 item for their order
CREATE PROCEDURE PO_items (IN po_id int, p_id int, quantity int)
BEGIN
declare applied_purchase_price	decimal(10,2);
declare total_per_item decimal(10,2);
declare PO_status enum('processing','shipped','delivered','cancelled');
set applied_purchase_price = (select purchase_price from product where product_id = p_id);
set total_per_item = applied_purchase_price * quantity;
set PO_status = (select distinct po.status from purchasing_order po where po.PO_id = po_id);

insert into PO_details (po_id, product_id, quantity, purchase_price)
	values (po_id, p_id, quantity, applied_purchase_price);
-- automatically re-calculate and update total order amount in Orders table
update purchasing_order
	set purchasing_order.total_before_tax = purchasing_order.total_before_tax + total_per_item
	where purchasing_order.po_id = po_id;
-- update inventory accordingly
if PO_status = 'processing' then 
	update inventory 
	set PO_IDs = trim(leading ',' from (concat(ifnull(PO_IDs,''),',',PO_ID))),
	quantity_PO = quantity_PO + quantity
    where product_id = p_id;
	elseif PO_status = 'shipped' or PO_status = 'delivered' then
    signal SQLSTATE '45000' set message_text = 'This PO is already shipped or delivered. You cannot add new items into this order.';
    end if;
end//
-- 
CREATE TRIGGER update_PO_status 
before update on purchasing_order for each row 
begin  
declare credit_term varchar(50);
declare updated_purchase_date timestamp;
declare remove_PO_id varchar(50);
declare updated_PO_IDs varchar(100);
set credit_term = (select supplier_credit_term from supplier where supplier_id = new.supplier_id);
set updated_purchase_date = current_timestamp();
set remove_PO_id = concat(new.po_id,',');

if new.status = 'shipped' and new.shipped_date is null then
	signal SQLSTATE '45000' set message_text = 'Shipped_date cannot be null. Please insert shipped_date.';
	end if;
if new.status = 'cancelled' then
	if old.status = 'shipped' or old.status = 'delivered' then
		signal SQLSTATE '45000' set message_text = 'This PO is already shipped/delivered. You cannot cancel it';
		end if;
    if old.status = 'processing' then 
		set new.estimate_arrival_time = null;
		update inventory i
		join purchasing_order po join po_details pod 
		on i.product_id = pod.product_id and pod.po_id = po.po_id
		set i.PO_IDs = (case when length(left(i.PO_IDs,locate(new.po_id,i.PO_IDs)-1)) > 0 and locate(',',i.PO_IDs,locate(new.po_id,i.PO_IDs)) <> 0 
					then replace(i.PO_IDs,remove_PO_ID,'') -- when new.PO_id is in middle of the string in PO_IDs column
                    else trim(both ',' from (replace(i.PO_IDs,new.po_id,'')))end), 
		i.quantity_PO = i.quantity_PO - pod.quantity
		where po.po_id = new.po_id;
		update supplier s
		join purchasing_order po on s.supplier_id = po.supplier_id
		set s.used_credit = s.used_credit - po.supplier_credit_used
		where po.supplier_id = new.supplier_id;
		delete AP 
		from accounts_payable AP join purchasing_order po on ap.po_id = po.po_id
		where po.po_id = new.po_id;
		end if;
	elseif new.status = 'delivered' then
	update inventory i
    join purchasing_order po join po_details pod 
    on i.product_id = pod.product_id and pod.po_id = po.po_id
    set i.PO_IDs = (case when length(left(i.PO_IDs,locate(new.po_id,i.PO_IDs)-1)) > 0 and locate(',',i.PO_IDs,locate(new.po_id,i.PO_IDs)) != 0 
					then replace(i.PO_IDs,remove_PO_ID,'') -- when new.PO_id is in middle of the string in PO_IDs column
                    else trim(both ',' from (replace(i.PO_IDs,new.po_id,'')))end), 
    i.quantity_PO = i.quantity_PO - pod.quantity,
    i.total_quantity = i.total_quantity + pod.quantity
    where po.po_id = new.po_id;
    if new.received_date is null then 
    signal SQLSTATE '45000' set message_text = 'If the shipment is delivered, its received date is required. Please insert received date.';
    end if;
    end if;
end//
-- 
CREATE TRIGGER update_PO_items 
before update on PO_details for each row 
begin
declare PO_status enum('processing','shipped','delivered','cancelled');
set PO_status = (select distinct po.status from purchasing_order po join PO_details pod on po.PO_id = pod.PO_id where po.PO_id = new.PO_id); 

if PO_status = 'shipped' or PO_status = 'delivered' then
	signal SQLSTATE '45000' set message_text = 'This order is already shipped/delivered. You cannot change the PO items!';
    elseif PO_status = 'processing' then 
   update inventory i
		join purchasing_order po join po_details pod 
		on i.product_id = pod.product_id and pod.po_id = po.po_id
		set i.quantity_PO = i.quantity_PO - old.quantity + new.quantity
    where pod.PO_id = new.PO_id;
    end if;
end //
--
CREATE TRIGGER before_update_supplier_credit
before update on supplier for each row 
begin
	if new.remaining_credit_limit < 0 then
    signal SQLSTATE '45000' set message_text = 'Insufficent supplier credits for this update. It would exceed the supplier_credit_limit';
    end if;
end //
