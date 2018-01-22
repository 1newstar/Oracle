
select d.*,
       (select max(sal) from emp e where e.deptno = 10) max_10,
       (select max(sal) from emp e where e.deptno = 20) max_20,
       (select max(sal) from emp e where e.deptno = 30) max_30,
       (select max(sal) from emp e where e.deptno = 40) max_40
  from dept d;

select * from dept;
select deptno, max(sal) from emp group by deptno;
select deptno,
       max(decode(deptno, 10, sal)) max_10,
       max(decode(deptno, 20, sal)) max_20,
       max(decode(deptno, 30, sal)) max_30,
       max(decode(deptno, 40, sal)) max_40
  from emp
 group by deptno;

with v as
 (select deptno,
         max(decode(deptno, 10, sal)) max_10,
         max(decode(deptno, 20, sal)) max_20,
         max(decode(deptno, 30, sal)) max_30,
         max(decode(deptno, 40, sal)) max_40
    from emp
   group by deptno),
v1 as
 (select v.*,
         lead(max_10 ignore nulls) over(order by deptno) lead_max_10,
         lag(max_10 ignore nulls) over(order by deptno) lag_max_10,
         lead(max_20 ignore nulls) over(order by deptno) lead_max_20,
         lag(max_20 ignore nulls) over(order by deptno) lag_max_20,
         lead(max_30 ignore nulls) over(order by deptno) lead_max_30,
         lag(max_30 ignore nulls) over(order by deptno) lag_max_30,
         lead(max_40 ignore nulls) over(order by deptno) lead_max_40,
         lag(max_40 ignore nulls) over(order by deptno) lag_max_40
    from v),
v3 as
 (select deptno,
         coalesce(max_10, lead_max_10, lag_max_10) max_10,
         coalesce(max_20, lead_max_20, lag_max_20) max_20,
         coalesce(max_30, lead_max_30, lag_max_30) max_30,
         coalesce(max_40, lead_max_40, lag_max_40) max_40
    from v1)
select dept.*, v3.max_10, v3.max_20, v3.max_30, v3.max_40
  from dept
  left join v3
    on (dept.deptno = v3.deptno);

select t2.deptno, t1.max_sal
  from (select deptno, max(sal) max_sal from emp group by deptno) t1
 right join dept t2
    on (t1.deptno = t2.deptno);
 


select *
  from dept t1
 cross join (select deptno, max(sal) max_sal from emp group by deptno) t2
order by t1.deptno , t2.deptno;

select t1.deptno,
       t1.dname,
       t1.loc,
       max(decode(t2.deptno, 10, max_sal)) max_10,
       max(decode(t2.deptno, 20, max_sal)) max_20,
       max(decode(t2.deptno, 30, max_sal)) max_30,
       max(decode(t2.deptno, 40, max_sal)) max_40
  from dept t1
 cross join (select deptno, max(sal) max_sal from emp group by deptno) t2
 group by t1.deptno, t1.dname, t1.loc;
 
 
 
select t1.*,
       t2.*,
       decode(t2.deptno, 10, max_sal) max_10,
       decode(t2.deptno, 20, max_sal) max_20,
       decode(t2.deptno, 30, max_sal) max_30,
       decode(t2.deptno, 40, max_sal) max_40
  from dept t1
 cross join (select deptno, max(sal) max_sal from emp group by deptno) t2
 order by t1.deptno, t2.deptno
