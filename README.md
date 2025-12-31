# Resource-Governor-Impact-Analysis
**Description: Compares SQL Server behavior with and without Resource Governor, showing how resource control improves stability and prioritizes important queries.**
**1. create a table with a large dataset of 1 million rows.**
```sql
DROP TABLE IF EXISTS BigTable;
GO

CREATE TABLE BigTable (
    ID INT IDENTITY(1,1) PRIMARY KEY,
    Value CHAR(200)
);
GO

SET NOCOUNT ON;

INSERT INTO BigTable (Value)
SELECT TOP (1000000)
       REPLICATE('Y', 200)
FROM master.sys.all_objects a
CROSS JOIN master.sys.all_objects b
CROSS JOIN master.sys.all_objects c;
GO

SELECT COUNT(*) AS TotalRows
FROM BigTable;
GO  --1,000,000
```
**3.configure Resource Governor from scratch and remove the previous settings.**
```sql
سضم÷
USE MASTER;
GO

-- Disable RG if already enabled
ALTER RESOURCE GOVERNOR DISABLE;
GO

-- Reset classifier
ALTER RESOURCE GOVERNOR
WITH (CLASSIFIER_FUNCTION = NULL);
GO

ALTER RESOURCE GOVERNOR RECONFIGURE;
GO
```
**4.create logins and application names,For each group.**
```SQL
USE Master;
GO
--	 create login and thier users
-- Accounting
CREATE LOGIN AccountingLogin
WITH PASSWORD = '123456';
GO

USE PRACTIE;
GO
CREATE USER AccountingUser
FOR LOGIN AccountingLogin;
GO
ALTER ROLE db_owner ADD MEMBER AccountingUser;
GO


USE Master;
GO
-- Management
CREATE LOGIN ManagementLogin
WITH PASSWORD = '123456';
GO

USE PRACTIE;
GO
CREATE USER ManagementUser
FOR LOGIN ManagementLogin;
GO
ALTER ROLE db_owner ADD MEMBER ManagementUser;
GO


USE Master;
GO
-- Sales
CREATE LOGIN SalesLogin
WITH PASSWORD = '123456';
GO

USE PRACTIE;
GO
CREATE USER SalesUser
FOR LOGIN SalesLogin;
GO
ALTER ROLE db_owner ADD MEMBER SalesUser;
GO


USE Master;
GO
-- Default
CREATE LOGIN DefaultLogin
WITH PASSWORD = '123456';
GO

USE PRACTIE;
GO
CREATE USER DefaultUser
FOR LOGIN DefaultLogin;
GO
ALTER ROLE db_owner ADD MEMBER DefaultUser;
GO
```
**4.enable Resource Governor.**
**4-1.create the resource pools for every login with an application name.**
```SQL
DROP RESOURCE POOL AccountingPool;
GO
-- Accounting Pool - 20%
CREATE RESOURCE POOL AccountingPool
WITH (
    MAX_CPU_PERCENT = 20
);
GO


DROP RESOURCE POOL ManagementPool;
GO
-- Management Pool - 30%
CREATE RESOURCE POOL ManagementPool
WITH (
    MAX_CPU_PERCENT = 30
);
GO


DROP RESOURCE POOL SalesPool;
GO
-- Sales Pool - 40%
CREATE RESOURCE POOL SalesPool
WITH (
    MAX_CPU_PERCENT = 40
);
GO

--Default Pool=10%
```
**4-2.
÷÷÷سض


















**Performance Comparison**
![Result in table](ResultTable.png)
