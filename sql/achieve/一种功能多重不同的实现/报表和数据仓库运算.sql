select job , 
       case deptno when 10 then sal end as 部门10工资 ,
       case deptno when 20 then sal end as 部门20工资 ,
       case deptno when 30 then sal end as 部门30工资 ,
       case deptno when 40 then sal end as 部门40工资 ,
        sal as 合计工资                        
      from emp order by 1;
      
select job , 
       sum(case deptno when 10 then sal end) as 部门10工资 ,
       sum(case deptno when 20 then sal end) as 部门20工资 ,
       sum(case deptno when 30 then sal end) as 部门30工资 ,
       sum(case deptno when 40 then sal end) as 部门40工资 ,
       sum(sal) as 合计工资                        
      from emp 
      group by job
      order by 1;      




select job, sal, deptno from emp;

drop table test purge;
create table test as
select *
  from (select deptno, sal from emp) t
pivot(count(*) as ct, sum(sal) as s
   for deptno in(10 deptno_10,
                 20 deptno_20,
                 30 deptno_30,
                 40 deptno_40))
 order by 1;
 
 


 
 
select 10 deptno , deptno_10_ct cnt, DEPTNO_10_S sal  from test 
union all
select 20 deptno , deptno_20_ct cnt, DEPTNO_20_S sal  from test 
union all
select 30 deptno , deptno_30_ct cnt, DEPTNO_30_S sal  from test 
union all
select 40 deptno , deptno_40_ct cnt, DEPTNO_40_S sal  from test ;

select * from test;

with v1 as
 (select deptno, cnt
    from test unpivot(cnt for deptno in(deptno_10_ct as 10,
                                        deptno_20_ct as 20,
                                        deptno_30_ct as 30,
                                        deptno_40_ct as 40))),
v2 as
 (select deptno, sal
    from test unpivot(sal for deptno in(deptno_10_s as 10,
                                        deptno_20_s as 20,
                                        deptno_30_s as 30,
                                        deptno_40_s as 40)))
select v1.deptno, v1.cnt, v2.sal
  from v1
 inner join v2
    on (v1.deptno = v2.deptno);


select *
  from test 
        unpivot include nulls(cnt for deptno1 in(deptno_10_ct as 10,
                                      deptno_20_ct as 20,
                                      deptno_30_ct as 30,
                                      deptno_40_ct as 40)) 
        unpivot include nulls(sal for deptno2 in(deptno_10_s as 10,
                                       deptno_20_s as 20,
                                       deptno_30_s as 30,
                                       deptno_40_s as 40))
where deptno1 = deptno2        ;                


select *
  from (select ename, job, to_char(sal) sal, null as empty_line from emp) t1 
  unpivot include nulls(new_column_value for new_column_name in(ename,
                                                                 job,
                                                                 sal,
                                                                 empty_line));
select emps
  from (select empno, ename emps, 1 i
          from emp
        union all
        select empno, job, 2 i
          from emp
        union all
        select empno, to_char(sal) sal, 3 i
          from emp
        union all
        select empno, null xx, 4 i
          from emp)
 order by empno desc, i;





select (case
         when job = lag(job) over(partition by job order by ename) then
          null
         else
          job
       end) job,
       ename
  from emp;


select lead(job) over(partition by job order by job, ename) job1,
       job,
       ename
  from emp;

select (case
         when lead(job) over(partition by job order by job, ename) = job then
          null
         else
          job
       end) job1,
       job,
       ename
  from emp
 order by job, job1 nulls last;


--------------------------------------------------------------
--------------------11.5 利用“行转列”进行计算-----------------
--------------------------------------------------------------

with v as
 (select deptno, sum(sal) sum_sal from emp e group by e.deptno),
v1 as
 (select *
    from v
  pivot(max(sum_sal) as sal
     for deptno in(10 dept_10, 20 dept_20, 30 dept_30)))
select v.*,
       (case
         when deptno = 10 then
          dept_20_sal || '-' || dept_10_sal || '=' ||
          (dept_20_sal - dept_10_sal)
         when deptno = 30 then
          dept_20_sal || '-' || dept_30_sal || '=' ||
          (dept_20_sal - dept_30_sal)
       end) as 差额
  from v
 cross join v1;

--------------------------------------------------------------
--------------------11.6 给数据分组-----------------
--------------------------------------------------------------
with v1 as
 (select ename from emp order by ename),
v2 as
 (select ename, rownum as rn from v1),
v3 as
 (select ceil(rn / 5) gp, ename from v2),
v4 as
 (select v3.*, row_number() over(partition by gp order by ename) rn from v3)
select /*gp,*/
       max(decode(rn, 1, ename)) c1,
       max(decode(rn, 2, ename)) c2,
       max(decode(rn, 3, ename)) c3,
       max(decode(rn, 4, ename)) c4,
       max(decode(rn, 5, ename)) c5
  from v4
 group by gp;


--------------------------------------------------------------
--------------------11.7 给数据分组-----------------
--------------------------------------------------------------

select EMPNO, ENAME , ntile(3) over(order by ename) from emp;

--------------------------------------------------------------
--------------------11.11 人员在工作间的分布 -----------------
--------------------------------------------------------------
