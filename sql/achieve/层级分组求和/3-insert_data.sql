﻿prompt Importing table t_region...
set feedback off
set define off
insert into t_region (REGION_ID, REGION_NAME, PARENT_REGION_ID, LEVEL_KIND, NEW_REGION_ID)
values ('244480F9CE274CD3B4782118B0E5EBCA', '中国', null, 1, null);

insert into t_region (REGION_ID, REGION_NAME, PARENT_REGION_ID, LEVEL_KIND, NEW_REGION_ID)
values ('2A2C45FCE1E84DAC928DBA2950180E83', '广东省', '244480F9CE274CD3B4782118B0E5EBCA', 2, null);

insert into t_region (REGION_ID, REGION_NAME, PARENT_REGION_ID, LEVEL_KIND, NEW_REGION_ID)
values ('8E1BB485DA424B4E9C9BD757A48C2572', '惠州市', '2A2C45FCE1E84DAC928DBA2950180E83', 3, null);

insert into t_region (REGION_ID, REGION_NAME, PARENT_REGION_ID, LEVEL_KIND, NEW_REGION_ID)
values ('9D760F6E36154FB7AACE06671C0947EF', '广州市', '2A2C45FCE1E84DAC928DBA2950180E83', 3, null);

insert into t_region (REGION_ID, REGION_NAME, PARENT_REGION_ID, LEVEL_KIND, NEW_REGION_ID)
values ('9F60DD6B7A7644B4892C9F025CBE11DF', '深圳市', '2A2C45FCE1E84DAC928DBA2950180E83', 3, null);

insert into t_region (REGION_ID, REGION_NAME, PARENT_REGION_ID, LEVEL_KIND, NEW_REGION_ID)
values ('27A7FAC8E1B04EA5A02C79ABBD1ACE61', '福田区', '9F60DD6B7A7644B4892C9F025CBE11DF', 4, null);

insert into t_region (REGION_ID, REGION_NAME, PARENT_REGION_ID, LEVEL_KIND, NEW_REGION_ID)
values ('4CC1054144184773849BB6B4CAA86C08', '南山区', '9F60DD6B7A7644B4892C9F025CBE11DF', 4, null);

insert into t_region (REGION_ID, REGION_NAME, PARENT_REGION_ID, LEVEL_KIND, NEW_REGION_ID)
values ('66963C44FE044AB5A0EB56D231643D16', '湖南省', '244480F9CE274CD3B4782118B0E5EBCA', 2, null);

insert into t_region (REGION_ID, REGION_NAME, PARENT_REGION_ID, LEVEL_KIND, NEW_REGION_ID)
values ('8248F8EECB674BAEBD9D69A20629F1CD', '浙江省', '244480F9CE274CD3B4782118B0E5EBCA', 2, null);

insert into t_region (REGION_ID, REGION_NAME, PARENT_REGION_ID, LEVEL_KIND, NEW_REGION_ID)
values ('F7239CC29E934909BBC1666BC4411283', '湖北省', '244480F9CE274CD3B4782118B0E5EBCA', 2, null);

insert into t_region (REGION_ID, REGION_NAME, PARENT_REGION_ID, LEVEL_KIND, NEW_REGION_ID)
values ('4304A258F40F4AFEBC97A6614AEF2045', '武汉市', 'F7239CC29E934909BBC1666BC4411283', 3, null);

insert into t_region (REGION_ID, REGION_NAME, PARENT_REGION_ID, LEVEL_KIND, NEW_REGION_ID)
values ('E87CE1579CC74338B5D0C9D8468092F7', '孝感市', 'F7239CC29E934909BBC1666BC4411283', 3, null);

insert into t_region (REGION_ID, REGION_NAME, PARENT_REGION_ID, LEVEL_KIND, NEW_REGION_ID)
values ('314B044F701E4F44BECD80342F2D0417', '孝南', 'E87CE1579CC74338B5D0C9D8468092F7', 4, null);

insert into t_region (REGION_ID, REGION_NAME, PARENT_REGION_ID, LEVEL_KIND, NEW_REGION_ID)
values ('F601343BB78E4658B373CBA42039CA51', '汉川', 'E87CE1579CC74338B5D0C9D8468092F7', 4, null);

prompt Done.




t_users表测试数据, 每个region下面10个用户
insert into t_users
  select sys_guid(), region_id
    from t_region, (select 1 from dual connect by level <= 10);



t_login表测试数据 , 每个用户10条登录数据
insert into t_login
  select sys_guid(), user_id, login_date
    from t_users,
         (select sysdate - (dbms_random.value * 10) login_date
            from dual
          connect by level <= 10); 

-- 再执行两次这个SQL
insert into t_login
select * from t_login;