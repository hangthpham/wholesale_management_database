delimiter // 
drop trigger if exists paid_AP;
drop trigger if exists paid_AR;
CREATE TRIGGER paid_AP 
before update on accounts_payable for each row 
begin 

if new.payment_date is not null and new.check_no is null then
    signal SQLSTATE '45000' set message_text = 'If the account payable is resolved, check_no column is required.';
    elseif new.payment_date is null and new.check_no is not null then
	signal SQLSTATE '45000' set message_text = 'If the account payable is resolved, payment_date column is required.';
    elseif new.payment_date is not null and new.check_no is not null 
		and old.payment_date is null and old.check_no is null then
    update supplier s
    join accounts_payable ap on s.supplier_id = ap.supplier_id 
    set s.used_credit = s.used_credit - ap.supplier_credit_used
    where ap.supplier_id = new.supplier_id and ap.po_id = new.po_id;
    update purchasing_order po
    join accounts_payable ap on po.po_id = ap.po_id
    set po.supplier_credit_used = po.supplier_credit_used - ap.supplier_credit_used
    where ap.po_id = new.po_id;
    end if;
end//
--
CREATE TRIGGER Paid_AR 
before update on accounts_receivable for each row
begin 

if new.payment_date is not null and new.check_no is null then
    signal SQLSTATE '45000' set message_text = 'If the account receivable is resolved, check_no column is required.';
    elseif new.payment_date is null and new.check_no is not null then
	signal SQLSTATE '45000' set message_text = 'If the account receivable is resolved, payment_date column is required.';
    elseif new.payment_date is not null and new.check_no is not null 
       and old.payment_date is null and old.check_no is null then
    update customer c
    join accounts_receivable ar on c.customer_id = ar.customer_id 
    set c.used_credit = c.used_credit - ar.customer_credit_used
    where ar.customer_id = new.customer_id and ar.order_id = new.order_id;
    update orders o
    join accounts_receivable ar on o.order_id = ar.order_id
    set o.customer_credit_used = o.customer_credit_used - ar.customer_credit_used
    where ar.order_id = new.order_id;
    end if;
end//

    
    
    
