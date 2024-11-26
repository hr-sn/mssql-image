CREATE TABLE [staging].[test_account]
(
	[Id] INT NOT NULL PRIMARY KEY
,	[AccountId] varchar(50) NOT NULL
,	[AccountName] varchar(100) NOT NULL
) 
WITH (DATA_COMPRESSION = PAGE)
