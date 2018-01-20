create table T_REGION
(
  region_id        VARCHAR2(50),
  region_name      VARCHAR2(50),
  parent_region_id VARCHAR2(50),
  level_kind       INTEGER
);


create table T_USERS
(
  user_id   VARCHAR2(50),
  region_id VARCHAR2(50)
);


create table T_LOGIN
(
  id         VARCHAR2(50),
  user_id    VARCHAR2(50),
  login_date DATE
);