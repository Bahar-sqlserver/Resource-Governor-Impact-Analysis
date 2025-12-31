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


DROP WORKLOAD GROUP AccountingGroup;
DROP WORKLOAD GROUP ManagementGroup;
DROP WORKLOAD GROUP SalesGroup;


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


--CREATE WORKLOAD GROUP
CREATE WORKLOAD GROUP AccountingGroup
USING AccountingPool;
GO

CREATE WORKLOAD GROUP ManagementGroup
USING ManagementPool;
GO

CREATE WORKLOAD GROUP SalesGroup
USING SalesPool;
GO


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
ALTER ROLE db_datareader ADD MEMBER AccountingUser;
GO 
ALTER ROLE db_datawriter ADD MEMBER AccountingUser;
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
ALTER ROLE db_datareader ADD MEMBER SalesUser;
GO 
ALTER ROLE db_datawriter ADD MEMBER SalesUser;
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
ALTER ROLE db_datareader ADD MEMBER DefaultUser;
GO 
ALTER ROLE db_datawriter ADD MEMBER DefaultUser;
GO



USE MASTER;
GO

CREATE FUNCTION dbo.Classifier1()
RETURNS sysname
WITH SCHEMABINDING
AS
BEGIN
    DECLARE @GroupName sysname;

    IF APP_NAME() = 'AccountingApp' 
	SET @GroupName = 'AccountingGroup';

	ELSE IF APP_NAME() = 'ManagementApp'
	SET @GroupName = 'ManagementGroup';

	ELSE IF APP_NAME() = 'SalesApp'
	SET @GroupName = 'SalesGroup'; 

	ELSE SET @GroupName = 'default';

    RETURN @GroupName;
END;
GO

ALTER RESOURCE GOVERNOR 
WITH (CLASSIFIER_FUNCTION = dbo.Classifier1);

ALTER RESOURCE GOVERNOR RECONFIGURE;
GO
--Creating a large dataset
USE PRACTICE;
GO

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


--Monitoring

USE PRACTICE;
GO

DROP TABLE IF EXISTS ResourceGovernorMonitoringLog;
GO

CREATE TABLE ResourceGovernorMonitoringLog (
    LogTime            DATETIME2(3),
    session_id         INT,
    workload_group     SYSNAME,
    total_elapsed_time BIGINT,
    cpu_time           BIGINT,
    wait_time          BIGINT,
    wait_type          NVARCHAR(60),
    pool_name          SYSNAME,
    pool_cpu_percent   INT,
    pool_cpu_usage_ms  BIGINT
);
GO

--Accounting
SELECT 
    SUSER_NAME() AS CurrentLogin,
    APP_NAME() AS CurrentAppName;
GO

WITH CTE AS (
    SELECT TOP 3000000 a.*
    FROM BigTable a
    CROSS JOIN BigTable b
    WHERE a.ID < 1000
)
SELECT *
FROM CTE
ORDER BY NEWID();
GO


--Sales
SELECT APP_NAME() AS CurrentAppName, SUSER_NAME() AS CurrentLogin;
GO

DBCC DROPCLEANBUFFERS;
GO

WITH CTE AS (
    SELECT TOP 3000000 a.*
    FROM BigTable a
    CROSS JOIN BigTable b
	    CROSS JOIN BigTable C
    WHERE a.ID < 10000
)
SELECT *
FROM CTE
ORDER BY NEWID();
GO


--Management
SELECT APP_NAME() AS CurrentAppName, SUSER_NAME() AS CurrentLogin;
GO
SELECT * FROM BigTable WHERE ID = 1;
GO 200





--Default
SELECT TOP 1 *
FROM BigTable
WHERE ID = 1000;
GO 25

INSERT INTO ResourceGovernorMonitoringLog
(
    LogTime,
    session_id,
    workload_group,
    total_elapsed_time,
    cpu_time,
    wait_time,
    wait_type,
    pool_name,
    pool_cpu_percent,
    pool_cpu_usage_ms
)
SELECT
    SYSDATETIME(),
    r.session_id,
    g.name,
    r.total_elapsed_time,
    r.cpu_time,
    r.wait_time,
    r.wait_type,
    p.name,
    p.max_cpu_percent,
    p.total_cpu_usage_ms
FROM sys.dm_exec_requests r
JOIN sys.dm_exec_sessions s ON r.session_id = s.session_id
JOIN sys.dm_resource_governor_workload_groups g ON s.group_id = g.group_id
JOIN sys.dm_resource_governor_resource_pools p ON g.pool_id = p.pool_id
WHERE r.session_id > 50;
GO


--Monitoring

SELECT 
    log.session_id,
    log.workload_group,
    s.program_name AS ApplicationName,
    AVG(log.total_elapsed_time) AS AvgLatency_ms,
    AVG(log.cpu_time) AS AvgCPUTime_ms,
    AVG(log.wait_time) AS AvgWaitTime_ms,
    log.wait_type,
    log.pool_name,
    AVG(log.pool_cpu_percent) AS AvgPoolCPUPercent,
    AVG(log.pool_cpu_usage_ms) AS AvgPoolCPUUsage_ms
FROM ResourceGovernorMonitoringLog log
JOIN sys.dm_exec_sessions s
    ON log.session_id = s.session_id
GROUP BY 
    log.session_id, 
    log.workload_group, 
    s.program_name,
    log.wait_type, 
    log.pool_name
ORDER BY log.workload_group, log.session_id;
GO





DELETE 
FROM ResourceGovernorMonitoringLog;
GO
DBCC DROPCLEANBUFFERS;
GO

-- And the same queries without resource governor
