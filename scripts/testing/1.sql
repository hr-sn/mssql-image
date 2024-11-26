set nocount on;
declare @table1 table (Id int, description1 varchar(50), dt datetime2(0))
declare @table2 table (Id int, description2 varchar(50), dt datetime2(0))

declare @etlcutoff datetime2(0) = (select dateadd(mi, -50, getdate()))
declare @dt1 datetime2(0) = (select dateadd(mi, -51, getdate()))
declare @dt2 datetime2(0) = (select dateadd(mi, -50, getdate()))
declare @dt datetime2(0) = getdate()

insert into @table1
values 
(1, 'test1', @dt1),
(2, 'test2', @dt1),
(3, 'test2', dateadd(mi, 2, @dt1))

insert into @table2
values 
(1, 'test21', @dt2),
(2, 'test22', @dt2),
(3, 'test22', dateadd(mi, -51, @dt2))

select t1.*
      ,'***'
      ,t2.*
      ,@etlcutoff As etlcutoff
      ,@dt as dt
from   @table1 As t1
       LEFT OUTER JOIN @table2 t2 ON
         t1.id = t2.id
where (t1.dt >= @etlcutoff OR t2.dt >= @etlcutoff)