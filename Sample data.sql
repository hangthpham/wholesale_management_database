-- Using created procedures to insert new data

call new_emp(null,'Jennifer','Simpson',9799328747,'salesrep@gmail.com','sales rep','Sales',null,60000,'12854 Caroline blvd','Atlanta','GA',30024,'2021-07-15');
call new_emp(null,'Vu','Truong',8609328747,'director@gmail.com','Marketing Director','marketing',null,110000,'19 BAC rd','Hartford','CT',06117,'2021-07-15');
call new_emp(null,'Stephan','Johnsson',8325038873,'president@gmail.com','Director of Sourcing Department','Sourcing',null,120000,'11619 Hazen St','Houston','TX',77072,'2009-09-01');

call new_customer(1,'Vespa Tech','Anna Vu',9348765646,'annav@gmail.com','active','2343 Enum Venue','San Francisco','CA','09234',3000,0,'30',500,3);
call new_customer(2,'Cognizant','Adam West',8609327583,'AWest@gmail.com','active','23258 Westfield Blvd','Dallas','TX','53429',1800,0,'90',400,3);
call new_customer(null,'Venmo Tech','Shinza Ki',9087652346,'ski@gmail.com','active','2234 Enum Venue','New York','New York','02433',6000,0,'60',200,3);

call new_supplier(null,'Coksa Inc','Ms. Vancine Roller',12354903134, 'vr@coksa.inc','active','124 Corasda Ave', 'Okla','KS', 24134, 'USA',10,100000,0,60,1);
call new_supplier(2,'Kaseas','Ms. Vannie Ngo',3244232748, 'vn@ks.com','active','12342 Palm Tree Ave', 'Ornsa','Adsarn', 34235, 'Taiwan',21,20000,0,30,1);
call new_supplier(null,'Metal Precision','Josh Vanure',2353424458, 'Jvanure@metalprecision.com','active','35235 Okasam Blvd', 'Oasdasn','Pzengshin', 432411, 'China',30,35000,0,60,2);

call new_product_inventory(1, 'Spa chair V19', 'Massage chair','Massage Chair V19','continued', 50,120.99, 300, 3);
call new_product_inventory(null, 'Spa chair V19', 'Massage chair','Massage Chair V19','continued', 50,100.99, 295, 2);
call new_product_inventory(null,'Accessory Cart V21','Cart','Accessory Cart V21','continued', 15,25,70,1);

call new_order (1,2,3,'2021-12-31','shipped/picked up',2,10,0,100,0);
call new_order (2,2,3,'2022-02-22','shipped/picked up',1,12,1000,0,200);
call new_order (3,1,3,'2022-03-22','quote',3,10,0,100,500);
call new_order (4,1,3,'2022-03-22','processing',3,7,0,100,300);
call new_order (5,3,3,'2021-12-22','processing',1,3,100,0,200);

call order_items (1,3,5);
call order_items(2,2,3);
call order_items(3,2,1);

call new_PO (1, 1, 2, '2022-03-01','processing',1,2, 50,100,50);
call new_PO(2,2,2,'2022-02-22','processing',1,5,100,200,100);
call new_PO(3,1,2,'2022-01-30','processing',2,4,200,180,150);
call new_PO (4,2,1,'2022-01-20','processing',2,3,0,50,100);
call new_PO(5,1,3,'2022-02-10','shipped',1,10,100,250,500);

call PO_items(1,2,3);
call PO_items (1,3,10);
call PO_items(2,2,2);
call PO_items(3,3,2);
call PO_items (4,1,2);
call PO_items (4,3,3);

