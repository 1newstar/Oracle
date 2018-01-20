http://bbs.csdn.net/topics/392298742

三张表：
1 region表：
字段：主键id   ，     parent_region_id  ，     level_kind(region级别)
2 user 表：
字段：主键id ，    region_id
3 login 表：
字段：主键id，    user_id,      date

其中region表数据是树形，以中国为例，中国是根region，level_kind = 1，
广东山东等为二级region,parent_region_id = 中国的id， level_kind为2，
现在要求查询出每天每个省登陆总人数和登陆总次数（省下边的地市，地市下边的乡镇，乡镇下边的区都要统计进该省内） 


