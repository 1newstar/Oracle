recommend_need_stock(user_code,NEED_CHANGE_STOCK)

RECOMMEND_MARKET_VALUE_STOCK(USER_CODE,NEED_CHANGE_STOCK,STK_star,market_stock,rn)
RECOMMEND_PE_STOCK(USER_CODE,NEED_CHANGE_STOCK,STK_star,pe_stock,rn)
RECOMMEND_INDUSTRY_STOCK(USER_CODE,NEED_CHANGE_STOCK,STK_star,in_stock,rn)
RECOMMEND_STYLE_STOCK(USER_CODE,NEED_CHANGE_STOCK,STK_star,style_stock,rn)



drop table test purge;
create table test(
  user_code varchar2(200),
  need_change_stock varchar2(200),
  market_stock varchar2(200),
  pe_stock varchar2(200),
  in_stock varchar2(200),
  style_stock varchar2(200),
  type char(1),
  rn int
);

insert into test (USER_CODE, NEED_CHANGE_STOCK, MARKET_STOCK, PE_STOCK, IN_STOCK, STYLE_STOCK, TYPE, RN)
values ('309820088988', '518049', '000001', null, null, null, '1', 1);

insert into test (USER_CODE, NEED_CHANGE_STOCK, MARKET_STOCK, PE_STOCK, IN_STOCK, STYLE_STOCK, TYPE, RN)
values ('309820088988', '518049', '000002', null, null, null, '1', 2);

insert into test (USER_CODE, NEED_CHANGE_STOCK, MARKET_STOCK, PE_STOCK, IN_STOCK, STYLE_STOCK, TYPE, RN)
values ('309820088988', '518049', null, '000003', null, null, '2', 1);

insert into test (USER_CODE, NEED_CHANGE_STOCK, MARKET_STOCK, PE_STOCK, IN_STOCK, STYLE_STOCK, TYPE, RN)
values ('309820088988', '518049', null, null, '000004', null, '3', 1);

insert into test (USER_CODE, NEED_CHANGE_STOCK, MARKET_STOCK, PE_STOCK, IN_STOCK, STYLE_STOCK, TYPE, RN)
values ('309820088988', '518049', null, null, '000005', null, '3', 2);

insert into test (USER_CODE, NEED_CHANGE_STOCK, MARKET_STOCK, PE_STOCK, IN_STOCK, STYLE_STOCK, TYPE, RN)
values ('309820088988', '518049', null, null, null, '000006', '4', 1);
commit;

select * from test where rn = 1;
select * from test where rn = 2;

with v as
 (select * from test where rn = 1)
select *
  from (select user_code,
               need_change_stock,
               type,
               max(decode(type,
                          1,
                          market_stock,
                          2,
                          pe_stock,
                          3,
                          in_stock,
                          4,
                          style_stock)) new_col
          from v
         group by user_code, need_change_stock, type) a
pivot (max(new_col) for type in('1' as market_stock,
                           '2' pe_stock,
                           '3' in_stock,
                           '4' style_stock));

------------------------------------------------------------------------------------------------------------------

select user_code,
       need_change_stock,
       market_stock,
       pe_stock,
       in_stock,
       style_stock,
       rn
  from (select user_code,
               need_change_stock,
               type,
               rn,
               max(decode(type,
                          1,
                          market_stock,
                          2,
                          pe_stock,
                          3,
                          in_stock,
                          4,
                          style_stock)) new_col
          from test
         group by user_code, need_change_stock, type, rn)
pivot(max(new_col)
   for type in('1' as market_stock,
               '2' pe_stock,
               '3' in_stock,
               '4' style_stock));

------------------------------------------------------------------------------------------------------------------

select user_code,
       need_change_stock,
       rn,
       max(decode(type, 1, market_stock)) market_stock,
       max(decode(type, 2, pe_stock)) pe_stock,
       max(decode(type, 3, in_stock)) in_stock,
       max(decode(type, 4, style_stock)) style_stock
  from test
 group by user_code, need_change_stock, rn;



