prompt Importing table t_staffer...
set feedback off
set define off
insert into t_staffer (ID, NAME, AGE, DEPT)
values (7369, 'SMITH', 29, '20');

insert into t_staffer (ID, NAME, AGE, DEPT)
values (7499, 'ALLEN', 26, '30');

insert into t_staffer (ID, NAME, AGE, DEPT)
values (7521, 'WARD', 25, '30');

insert into t_staffer (ID, NAME, AGE, DEPT)
values (7566, 'JONES', 25, '20');

insert into t_staffer (ID, NAME, AGE, DEPT)
values (7654, 'MARTIN', 34, '30');

insert into t_staffer (ID, NAME, AGE, DEPT)
values (7698, 'BLAKE', 33, '30');

insert into t_staffer (ID, NAME, AGE, DEPT)
values (7782, 'CLARK', 38, '10');

insert into t_staffer (ID, NAME, AGE, DEPT)
values (7788, 'SCOTT', 32, '20');

insert into t_staffer (ID, NAME, AGE, DEPT)
values (7839, 'KING', 29, '10');

insert into t_staffer (ID, NAME, AGE, DEPT)
values (7844, 'TURNER', 21, '30');

insert into t_staffer (ID, NAME, AGE, DEPT)
values (7876, 'ADAMS', 38, '20');

insert into t_staffer (ID, NAME, AGE, DEPT)
values (7900, 'JAMES', 21, '30');

insert into t_staffer (ID, NAME, AGE, DEPT)
values (7902, 'FORD', 36, '20');

insert into t_staffer (ID, NAME, AGE, DEPT)
values (7934, 'MILLER', 33, '10');

prompt Done.




insert into t_worktime 
select id,
       lpad(trunc(dbms_random.value(8, 10)), 2, '0') || ':' ||
       lpad(trunc(dbms_random.value(0, 59)), 2, '0') intime,
       
       lpad(trunc(dbms_random.value(17, 21)), 2, '0') || ':' ||
       lpad(trunc(dbms_random.value(0, 59)), 2, '0') outtime,
       daynum
  from t_staffer, (select level daynum from dual connect by level <= 30)
 order by id, daynum;

commit;



-- 随机删除几条数据， 制造缺勤
delete t_worktime
 where rowid in (select rid
                   from (select rowid rid,
                                daynumber,
                                trunc(dbms_random.value(1, 50)) random
                           from t_worktime t)
                  where random = daynumber);
commit;