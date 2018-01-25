vim sales.txt
# 将下面的内容粘贴到sales.txt文件中
1,nike,20180901,20180905
2,nike,20180903,20180906
3,nike,20180909,20180915
4,oppo,20180804,20180805
5,oppo,20180804,20180815
6,vivo,20180815,20180821
7,vivo,20180902,20180912

# 上传到hdfs中
hdfs dfs -put sales.txt /data/

#创建hive表
create table t_sales(id int,brand string,startdate string,enddate string)
row format delimited
fields terminated by ',';

#加载数据
load data inpath '/data/sales.txt' into table t_sales;





select t.id, t.brand,
       --datediff(t.startdate, t.enddate),
       from_unixtime(unix_timestamp(t.startdate, 'yyyyMMdd')),
       from_unixtime(unix_timestamp(t.enddate, 'yyyyMMdd')),
       datediff(from_unixtime(unix_timestamp(t.enddate, 'yyyyMMdd')),from_unixtime(unix_timestamp(t.startdate, 'yyyyMMdd'))) + 1
  from t_sales t;
+-------+----------+----------------------+----------------------+------+--+
| t.id  | t.brand  |         _c2          |         _c3          | _c4  |
+-------+----------+----------------------+----------------------+------+--+
| 1     | nike     | 2018-09-01 00:00:00  | 2018-09-05 00:00:00  | 5    |
| 2     | nike     | 2018-09-03 00:00:00  | 2018-09-06 00:00:00  | 4    |
| 3     | nike     | 2018-09-09 00:00:00  | 2018-09-15 00:00:00  | 7    |
| 4     | oppo     | 2018-08-04 00:00:00  | 2018-08-05 00:00:00  | 2    |
| 5     | oppo     | 2018-08-04 00:00:00  | 2018-08-15 00:00:00  | 12   |
| 6     | vivo     | 2018-08-15 00:00:00  | 2018-08-21 00:00:00  | 7    |
| 7     | vivo     | 2018-09-02 00:00:00  | 2018-09-12 00:00:00  | 11   |
+-------+----------+----------------------+----------------------+------+--+



select v1.*,
       lag(enddate) over(partition by v1.brand order by startdate) prev_enddate
  from (select t.id,
               t.brand,
               from_unixtime(unix_timestamp(t.startdate, 'yyyyMMdd')) startdate,
               from_unixtime(unix_timestamp(t.enddate, 'yyyyMMdd')) enddate
          from t_sales t) v1;
+--------+-----------+----------------------+----------------------+----------------------+--+
| v1.id  | v1.brand  |     v1.startdate     |      v1.enddate      |     prev_enddate     |
+--------+-----------+----------------------+----------------------+----------------------+--+
| 1      | nike      | 2018-09-01 00:00:00  | 2018-09-05 00:00:00  | NULL                 |
| 2      | nike      | 2018-09-03 00:00:00  | 2018-09-06 00:00:00  | 2018-09-05 00:00:00  |
| 3      | nike      | 2018-09-09 00:00:00  | 2018-09-15 00:00:00  | 2018-09-06 00:00:00  |
| 5      | oppo      | 2018-08-04 00:00:00  | 2018-08-15 00:00:00  | NULL                 |
| 4      | oppo      | 2018-08-04 00:00:00  | 2018-08-05 00:00:00  | 2018-08-15 00:00:00  |
| 6      | vivo      | 2018-08-15 00:00:00  | 2018-08-21 00:00:00  | NULL                 |
| 7      | vivo      | 2018-09-02 00:00:00  | 2018-09-12 00:00:00  | 2018-08-21 00:00:00  |
+--------+-----------+----------------------+----------------------+----------------------+--+


select datediff('2018-09-05 00:00:00','2018-09-01 00:00:00');



select v2.*,
       (case
         when prev_enddate is null or startdate > prev_enddate then
          datediff(enddate, startdate) + 1
         else
          datediff(enddate, prev_enddate)
       end) days
  from (select v1.*,
               lag(enddate) over(partition by v1.brand order by enddate) prev_enddate
          from (select t.id,
                       t.brand,
                       from_unixtime(unix_timestamp(t.startdate, 'yyyyMMdd')) startdate,
                       from_unixtime(unix_timestamp(t.enddate, 'yyyyMMdd')) enddate
                  from t_sales t) v1) v2;
+--------+-----------+----------------------+----------------------+----------------------+-------+--+
| v2.id  | v2.brand  |     v2.startdate     |      v2.enddate      |   v2.prev_enddate    | days  |
+--------+-----------+----------------------+----------------------+----------------------+-------+--+
| 1      | nike      | 2018-09-01 00:00:00  | 2018-09-05 00:00:00  | NULL                 | 5     |
| 2      | nike      | 2018-09-03 00:00:00  | 2018-09-06 00:00:00  | 2018-09-05 00:00:00  | 1     |
| 3      | nike      | 2018-09-09 00:00:00  | 2018-09-15 00:00:00  | 2018-09-06 00:00:00  | 7     |
| 4      | oppo      | 2018-08-04 00:00:00  | 2018-08-05 00:00:00  | NULL                 | 2     |
| 5      | oppo      | 2018-08-04 00:00:00  | 2018-08-15 00:00:00  | 2018-08-05 00:00:00  | 10    |
| 6      | vivo      | 2018-08-15 00:00:00  | 2018-08-21 00:00:00  | NULL                 | 7     |
| 7      | vivo      | 2018-09-02 00:00:00  | 2018-09-12 00:00:00  | 2018-08-21 00:00:00  | 11    |
+--------+-----------+----------------------+----------------------+----------------------+-------+--+



with v3 as
 (select v2.*,
         (case
           when prev_enddate is null or startdate > prev_enddate then
            datediff(enddate, startdate) + 1
           else
            datediff(enddate, prev_enddate)
         end) days
    from (select v1.*,
                 lag(enddate) over(partition by v1.brand order by enddate) prev_enddate
            from (select t.brand,
                         from_unixtime(unix_timestamp(t.startdate, 'yyyyMMdd')) startdate,
                         from_unixtime(unix_timestamp(t.enddate, 'yyyyMMdd')) enddate
                    from t_sales t) v1) v2)
select brand, sum(days) all_days from v3 group by brand;

+--------+-----------+--+
| brand  | all_days  |
+--------+-----------+--+
| nike   | 13        |
| oppo   | 12        |
| vivo   | 18        |
+--------+-----------+--+
