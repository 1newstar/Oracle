prompt Importing table t_region...
set feedback off
set define off
insert into t_region (REGION_ID, REGION_NAME, PARENT_REGION_ID, LEVEL_KIND)
values ('111', '中国', null, 1);

insert into t_region (REGION_ID, REGION_NAME, PARENT_REGION_ID, LEVEL_KIND)
values ('222', '广东省', '111', 2);

insert into t_region (REGION_ID, REGION_NAME, PARENT_REGION_ID, LEVEL_KIND)
values ('555', '深圳市', '222', 3);

insert into t_region (REGION_ID, REGION_NAME, PARENT_REGION_ID, LEVEL_KIND)
values ('ccc', '广州市', '222', 3);

insert into t_region (REGION_ID, REGION_NAME, PARENT_REGION_ID, LEVEL_KIND)
values ('333', '湖北省', '111', 2);

insert into t_region (REGION_ID, REGION_NAME, PARENT_REGION_ID, LEVEL_KIND)
values ('aaa', '湖南省', '111', 2);

insert into t_region (REGION_ID, REGION_NAME, PARENT_REGION_ID, LEVEL_KIND)
values ('bbb', '浙江省', '111', 2);

insert into t_region (REGION_ID, REGION_NAME, PARENT_REGION_ID, LEVEL_KIND)
values ('ggg', '福田区', '555', 4);

insert into t_region (REGION_ID, REGION_NAME, PARENT_REGION_ID, LEVEL_KIND)
values ('hhh', '南山区', '555', 4);

insert into t_region (REGION_ID, REGION_NAME, PARENT_REGION_ID, LEVEL_KIND)
values ('ddd', '惠州市', '222', 3);

insert into t_region (REGION_ID, REGION_NAME, PARENT_REGION_ID, LEVEL_KIND)
values ('eee', '武汉市', '333', 3);

insert into t_region (REGION_ID, REGION_NAME, PARENT_REGION_ID, LEVEL_KIND)
values ('fff', '孝感市', '333', 3);

insert into t_region (REGION_ID, REGION_NAME, PARENT_REGION_ID, LEVEL_KIND)
values ('zzz', '汉川', 'fff', 4);

insert into t_region (REGION_ID, REGION_NAME, PARENT_REGION_ID, LEVEL_KIND)
values ('yyy', '孝南', 'fff', 4);

prompt Done.
