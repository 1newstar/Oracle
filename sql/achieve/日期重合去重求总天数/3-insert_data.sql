prompt Importing table t_sale...
set feedback off
set define off
insert into t_sale (ID, BRAND, STARTDATE, ENDDATE)
values (1, 'nike', to_date('01-09-2017', 'dd-mm-yyyy'), to_date('05-09-2017', 'dd-mm-yyyy'));

insert into t_sale (ID, BRAND, STARTDATE, ENDDATE)
values (2, 'nike', to_date('03-09-2017', 'dd-mm-yyyy'), to_date('06-09-2017', 'dd-mm-yyyy'));

insert into t_sale (ID, BRAND, STARTDATE, ENDDATE)
values (3, 'nike', to_date('09-09-2017', 'dd-mm-yyyy'), to_date('15-09-2017', 'dd-mm-yyyy'));

insert into t_sale (ID, BRAND, STARTDATE, ENDDATE)
values (4, 'oppo', to_date('04-08-2017', 'dd-mm-yyyy'), to_date('05-08-2017', 'dd-mm-yyyy'));

insert into t_sale (ID, BRAND, STARTDATE, ENDDATE)
values (5, 'oppo', to_date('04-08-2017', 'dd-mm-yyyy'), to_date('15-08-2017', 'dd-mm-yyyy'));

insert into t_sale (ID, BRAND, STARTDATE, ENDDATE)
values (6, 'vivo', to_date('15-08-2017', 'dd-mm-yyyy'), to_date('21-08-2017', 'dd-mm-yyyy'));

insert into t_sale (ID, BRAND, STARTDATE, ENDDATE)
values (7, 'vivo', to_date('02-09-2017', 'dd-mm-yyyy'), to_date('12-09-2017', 'dd-mm-yyyy'));

prompt Done.
