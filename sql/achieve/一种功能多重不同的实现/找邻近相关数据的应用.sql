-- 原需求网址 https://dba.stackexchange.com/questions/189333/select-where-next-rows-value-is-greater/189336#189336
--测试数据
create table road_insp
   (    
    insp_id int,
    road_id int,
    insp_date date, 
    condition number(38,2)
   ) ;
insert into road_insp (insp_id, road_id, insp_date, condition) values (1,1,to_date('01-01-01','DD-MM-YY'),10);
insert into road_insp (insp_id, road_id, insp_date, condition) values (2,1,to_date('01-01-04','DD-MM-YY'),09);
insert into road_insp (insp_id, road_id, insp_date, condition) values (3,1,to_date('01-01-07','DD-MM-YY'),08);
insert into road_insp (insp_id, road_id, insp_date, condition) values (4,1,to_date('01-01-10','DD-MM-YY'),06);

insert into road_insp (insp_id, road_id, insp_date, condition) values (5,2,to_date('01-01-02','DD-MM-YY'),10);
insert into road_insp (insp_id, road_id, insp_date, condition) values (6,2,to_date('01-01-05','DD-MM-YY'),08);

insert into road_insp (insp_id, road_id, insp_date, condition) values (7,4,to_date('01-01-03','DD-MM-YY'),10);
insert into road_insp (insp_id, road_id, insp_date, condition) values (8,4,to_date('01-01-06','DD-MM-YY'),12);
insert into road_insp (insp_id, road_id, insp_date, condition) values (9,4,to_date('01-01-09','DD-MM-YY'),08);

insert into road_insp (insp_id, road_id, insp_date, condition) values (10,5,to_date('01-01-01','DD-MM-YY'),10);
insert into road_insp (insp_id, road_id, insp_date, condition) values (11,5,to_date('01-01-03','DD-MM-YY'),09);
insert into road_insp (insp_id, road_id, insp_date, condition) values (12,5,to_date('01-01-06','DD-MM-YY'),08);
insert into road_insp (insp_id, road_id, insp_date, condition) values (13,5,to_date('01-01-09','DD-MM-YY'),07);
insert into road_insp (insp_id, road_id, insp_date, condition) values (14,5,to_date('01-01-12','DD-MM-YY'),06);
insert into road_insp (insp_id, road_id, insp_date, condition) values (15,5,to_date('01-01-15','DD-MM-YY'),05);
insert into road_insp (insp_id, road_id, insp_date, condition) values (16,5,to_date('01-01-18','DD-MM-YY'),20);




from
    road_insp
order by
    road_id,
    insp_date



   INSP_ID    ROAD_ID   INSP_DATE  CONDITION
---------- ----------   --------- ----------
         1          1   01-JAN-01         10
         2          1   01-JAN-04          9
         3          1   01-JAN-07          8
         4          1   01-JAN-10          6

         5          2   01-JAN-02         10
         6          2   01-JAN-05          8

         7          4   01-JAN-03         10
         8          4   01-JAN-06         12 <-error
         9          4   01-JAN-09          8

        10          5   01-JAN-01         10
        11          5   01-JAN-03          9
        12          5   01-JAN-06          8
        13          5   01-JAN-09          7
        14          5   01-JAN-12          6
        15          5   01-JAN-15          5
        16          5   01-JAN-18         20 <-error

		




   
--select case when date '2009-01-01' > date '2006-01-01' then 'gt' else 'lt' end from dual

-----------lag方式
select *
  from (select t.*,
               lag(condition) over(partition by road_id order by insp_date) prev_condition
          from road_insp t)
 where condition > prev_condition;

-----------lead方式
select *
  from (select t.*,
               lead(condition) over(partition by road_id order by insp_date desc) next_condition
          from road_insp t)
 where condition >next_condition;
 
 
-----------first_value实现类似lag功能来实现这个功能 
select *
  from (select a.*,
               first_value(condition) over(partition by road_id order by insp_date rows between 1 preceding and unbounded following) next_cond
          from road_insp a)
 where condition > next_cond

