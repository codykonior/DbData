[System.Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidUsingConvertToSecureStringWithPlainText', '')]
param (
)

Describe "DbData" {
    Import-Module .\DbData -Force
    Get-ChildItem $PSScriptRoot Test-*.ps1 | ForEach-Object {
        . $_.FullName
    }
    $ServerInstance = "localhost"
    $userId = "sa"
    $password = "Password12!"

    $securePassword = ConvertTo-SecureString $password -AsPlainText -Force
    $securePassword.MakeReadOnly()
    $badSecurePassword = ConvertTo-SecureString "ABC" -AsPlainText -Force
    $badSecurePassword.MakeReadOnly()
    $credential = New-Object System.Management.Automation.PSCredential($userId, $securePassword)
    $badCredential = New-Object System.Management.Automation.PSCredential($userId, $badSecurePassword)
    $sqlCredential = New-Object System.Data.SqlClient.SqlCredential($userId, $securePassword)
    $badSqlCredential = New-Object System.Data.SqlClient.SqlCredential($userId, $badSecurePassword)

    $setup = "IF OBJECT_ID('dbo.MyData') IS NOT NULL DROP TABLE dbo.MyData; CREATE TABLE dbo.MyData ([Id] INT IDENTITY(1, 1) PRIMARY KEY, SSN VARCHAR(11));"
    New-DbConnection $ServerInstance -SqlCredential $sqlCredential | New-DbCommand $setup | Get-DbData -OutputAs NonQuery | Out-Null

    Context "New-DbConnection" {
        It "returns a connection string" {
            $connection = New-DbConnection $ServerInstance -AsString
            $connection.GetType().FullName | Should -Be "System.String"
            $connection | Should -Be "Data Source=$($serverInstance);Integrated Security=True"
        }
        It "handles Pooling properly whether as a [bool] or string" {
            $connection = New-DbConnection $ServerInstance -AsString -Pooling True
            $connection | Should -BeLike "*Pooling=True*"
            $connection = New-DbConnection $ServerInstance -AsString -Pooling $True
            $connection | Should -BeLike "*Pooling=True*"
            $connection = New-DbConnection $ServerInstance -AsString -Pooling False
            $connection | Should -BeLike "*Pooling=False*"
            $connection = New-DbConnection $ServerInstance -AsString -Pooling $False
            $connection | Should -BeLike "*Pooling=False*"
        }
        It "returns a SqlConnection" {
            $connection = New-DbConnection $ServerInstance
            $connection.GetType().FullName | Should -Be "System.Data.SqlClient.SqlConnection"
            $connection.ConnectionString | Should -Be "Data Source=$($serverInstance);Integrated Security=True"
        }
        It "uses the provided database" {
            $connection = New-DbConnection $ServerInstance
            $connection.Database | Should -BeNullOrEmpty
            $connection = New-DbConnection $ServerInstance "master"
            $connection.Database | Should -Be "master"
        }
        It "fails to connect with an incorrect credential" {
            {  New-DbConnection $ServerInstance -UserID $userId -Password "" -Open } | Should -Throw
        }
        It "connects with a SQL credential" {
            { New-DbConnection $ServerInstance -UserID $userId -Password $password -Open } | Should -Not -Throw
        }
        It "connects with a secure credential if it's correct" {
            { New-DbConnection $ServerInstance -SqlCredential $credential -Open } | Should -Not -Throw
            { New-DbConnection $ServerInstance -SqlCredential $badCredential -Open } | Should -Throw
        }
        It "connects with a secure SQL credential" {
            { New-DbConnection $ServerInstance -SqlCredential $sqlCredential -Open } | Should -Not -Throw
            { New-DbConnection $ServerInstance -SqlCredential $badSqlCredential -Open } | Should -Throw
        }
    }

    Context "Use-DbRetry" {
        It "retries 3 times by default on query timeouts" {
            $output = try {
                Use-DbRetry {
                    New-DbConnection $ServerInstance -SqlCredential $credential | New-DbCommand "WAITFOR DELAY '00:00:10'" -CommandTimeout 1 | Get-DbData
                } -Verbose *>&1
            } catch {
                "Catch"
            }
            $output[0] | Should -Match "Try 1"
            $output[1] | Should -Match "Try 2"
            $output[2] | Should -Match "Try 3"
            $output[3] | Should -Match "Catch"
        }
    }

    Context "Get-DbSmo" {
        <#It "uses New-DbConnection so it can be redirected with `$PSDefaultParameterValues" {
            Mock -ModuleName DbData New-DbConnection { Write-Error "Caught" }
            try {
                Get-DbSmo $ServerInstance
            } catch {
            }
            Assert-MockCalled -ModuleName DbData New-DbConnection 1
        }
        # Unmock
        Import-Module DbData -Force
#>
        It "works with a server name directly" {
            { Get-DbSmo $ServerInstance } | Should -Not -Throw
        }
        It "works with a server name pipe" {
            { $ServerInstance | Get-DbSmo } | Should -Not -Throw
        }
        It "works with a server name pipe property" {
            { [PSCustomObject] @{ ServerInstance = $ServerInstance } | Get-DbSmo } | Should -Not -Throw
        }

        $connectionString = New-DbConnection $ServerInstance -AsString
        It "works with a connection string directly" {
            { Get-DbSmo -ConnectionString $connectionString } | Should -Not -Throw
        }
        It "works with a connection string pipe property" {
            { [PSCustomObject] @{ ConnectionString = $connectionString } | Get-DbSmo } | Should -Not -Throw
        }

        It "works with a SqlConnection directly" {
            { Get-DbSmo (New-DbConnection $ServerInstance) } | Should -Not -Throw
        }
        It "works with a SqlConnection pipe" {
            { New-DbConnection $ServerInstance | Get-DbSmo } | Should -Not -Throw
        }
        It "works with a SqlConnection pipe property" {
            { [PSCustomObject] @{ SqlConnection = New-DbConnection $ServerInstance } | Get-DbSmo } | Should -Not -Throw
        }
    }

    Context "Get-DbData output" {
        It "might return one data row" {
            $output = New-DbConnection $ServerInstance -SqlCredential $sqlCredential |
                New-DbCommand "SELECT 99 AS Something;" | Get-DbData
            $output.GetType().FullName | Should -Be "System.Data.DataRow"
            $output.Something | Should -Be 99
        }
        It "it might return more data rows" {
            $output = New-DbConnection $ServerInstance -SqlCredential $sqlCredential |
                New-DbCommand "SELECT 99 AS Something; SELECT 100 AS Something;" | Get-DbData
            $output.Count | Should -Be 2
            $output[0].GetType().FullName | Should -Be "System.Data.DataRow"
            $output[0].Something | Should -Be 99
            $output[1].GetType().FullName | Should -Be "System.Data.DataRow"
            $output[1].Something | Should -Be 100
        }
        It "returns data tables on request" {
            $output = New-DbConnection $ServerInstance -SqlCredential $sqlCredential |
                New-DbCommand "SELECT 99 AS Something;" | Get-DbData -OutputAs DataTable
            $output.GetType().FullName | Should -Be "System.Data.DataTable"
            $output.TableName | Should -Be "Table"
            $output.Rows.Count | Should -Be 1
            $output.Rows[0].Something | Should -Be 99
        }
        It "returns named data tables on request" {
            $output = New-DbConnection $ServerInstance -SqlCredential $sqlCredential |
                New-DbCommand "SELECT 99 AS Something;" | Get-DbData -OutputAs DataTable -TableMapping "MyTable"
            $output.GetType().FullName | Should -Be "System.Data.DataTable"
            $output.TableName | Should -Be "MyTable"
            $output.Rows.Count | Should -Be 1
            $output.Rows[0].Something | Should -Be 99
        }
        It "returns a dataset on request" {
            $output = New-DbConnection $ServerInstance -SqlCredential $sqlCredential |
                New-DbCommand "SELECT 99 AS Something;" | Get-DbData -OutputAs DataSet
            $output.GetType().FullName | Should -Be "System.Data.DataSet"
            $output.Tables[0].Rows.Count | Should -Be 1
            $output.Tables[0].Rows[0].Something | Should -Be 99
        }
        It "returns a dataset with named tables on request" {
            $output = New-DbConnection $ServerInstance -SqlCredential $sqlCredential |
                New-DbCommand "SELECT 99 AS Something;" | Get-DbData -OutputAs DataSet -TableMapping "MyTable"
            $output.GetType().FullName | Should -Be "System.Data.DataSet"
            $output.Tables[0].TableName | Should -Be "MyTable"
            $output.Tables["MyTable"].Rows.Count | Should -Be 1
            $output.Tables["MyTable"].Rows[0].Something | Should -Be 99
        }
        It "returns a scalar on request" {
            $output = New-DbConnection $ServerInstance -SqlCredential $sqlCredential |
                New-DbCommand "SELECT 99 AS Something;" | Get-DbData -OutputAs Scalar
            $output | Should -Be 99
        }
        It "returns nothing on request" {
            $output = New-DbConnection $ServerInstance -SqlCredential $sqlCredential |
                New-DbCommand "SELECT 99 AS Something;" | Get-DbData -OutputAs NonQuery
            $output | Should -Be -1
        }
    }

    Context "Get-DbData other handling" {
        It "captures PRINT statements" {
            $output = New-DbConnection $ServerInstance -SqlCredential $sqlCredential |
                New-DbCommand "PRINT 'Hi'" | Get-DbData -Verbose *>&1
            $output | Should -Match "Hi"
        }
        It "redirects PRINT statements to an ArrayList" {
            $output = New-Object System.Collections.ArrayList
            New-DbConnection $ServerInstance -SqlCredential $sqlCredential |
                New-DbCommand "PRINT 'Hi'" | Get-DbData -InfoMessageVariable $output
            $output | Should -Match "Hi"
        }
        It "continues on errors <= severity 10" {
            { New-DbConnection $ServerInstance -SqlCredential $sqlCredential |
                    New-DbCommand "SELECT 99; RAISERROR('Severe Error', 10, 1) WITH NOWAIT; SELECT 100;" | Get-DbData } | Should -Not -Throw
        }
        It "aborts on errors > severity 10" {
            { New-DbConnection $ServerInstance -SqlCredential $sqlCredential |
                    New-DbCommand "SELECT 99; RAISERROR('Severe Error', 11, 1) WITH NOWAIT; SELECT 100;" | Get-DbData } | Should -Throw
        }
        It "continues on errors <= severity 16 if fireinfo is configured" {
            { New-DbConnection $ServerInstance -SqlCredential $sqlCredential -FireInfoMessageEventOnUserErrors |
                    New-DbCommand "SELECT 99; RAISERROR('Severe Error', 16, 1) WITH NOWAIT; SELECT 100;" | Get-DbData } | Should -Not -Throw
        }
        It "aborts on errors >= severity 17 even if fireinfo is configured" {
            { New-DbConnection $ServerInstance -SqlCredential $sqlCredential -FireInfoMessageEventOnUserErrors |
                    New-DbCommand "SELECT 99; RAISERROR('Severe Error', 17, 1) WITH NOWAIT; SELECT 100;" | Get-DbData } | Should -Throw
        }
    }

    Context ".Alter() DataTable manipulation" {
        It "inserts data" {
            # Insert two SSNs
            $query = "SELECT * FROM dbo.MyData ORDER BY SSN;"
            $dt = New-DbConnection $ServerInstance -SqlCredential $sqlCredential | New-DbCommand $query | Get-DbData -OutputAs DataTable
            $dt.Alter(@(@{
                        SSN = "111-11-1111"
                    }, @{
                        SSN = "111-11-1112"
                    })) | Should -Be 1, 1

            # Check the SSNs are both there
            $dt = New-DbConnection $ServerInstance -SqlCredential $sqlCredential | New-DbCommand $query | Get-DbData -OutputAs DataRow
            $dt | Select-Object -First 1 -ExpandProperty SSN | Should -Be "111-11-1111"
            $dt | Select-Object -Last 1 -ExpandProperty SSN | Should -Be "111-11-1112"
        }
        It "updates data" {
            # Change one of the SSNs
            $query = "SELECT * FROM dbo.MyData ORDER BY SSN;"
            $dt = New-DbConnection $ServerInstance -SqlCredential $sqlCredential | New-DbCommand $query | Get-DbData -OutputAs DataTable
            $dt.Alter(@{
                    Id  = 1
                    SSN = "111-11-1113"
                }) | Should -Be 1

            # Confirm it has changed
            $dt = New-DbConnection $ServerInstance -SqlCredential $sqlCredential | New-DbCommand $query | Get-DbData -OutputAs DataRow
            $dt | Select-Object -ExpandProperty SSN | Should -Not -Be "111-11-1111"
            $dt | Select-Object -Last 1 -ExpandProperty SSN | Should -Be "111-11-1113"
        }
        It "deletes data" {
            # Delete only the SSN we don't want
            $query = "SELECT * FROM dbo.MyData WHERE SSN = @SSN;"
            $dt = New-DbConnection $ServerInstance -SqlCredential $sqlCredential | New-DbCommand $query -Parameters @{ SSN = '111-11-1113'; } | Get-DbData -OutputAs DataTable
            $dt | Should -Not -BeNullOrEmpty
            $dt.Rows.Delete()
            $dt.Alter() | Should -Be 1

            # Confirm it is gone
            $dt = New-DbConnection $ServerInstance -SqlCredential $sqlCredential | New-DbCommand $query -Parameters @{ SSN = '111-11-1113'; } | Get-DbData -OutputAs DataTable
            $dt | Should -BeNullOrEmpty

            # Confirm the other SSN remains
            $dt = New-DbConnection $ServerInstance -SqlCredential $sqlCredential | New-DbCommand $query -Parameters @{ SSN = '111-11-1112'; } | Get-DbData -OutputAs DataRow
            $dt | Should -Not -BeNullOrEmpty
        }
    }

    Context "Transactions" {
        It "rolls back" {
            <#
            $query = "SELECT * FROM dbo.MyData ORDER BY SSN;"
            $dt = New-DbConnection $ServerInstance -SqlCredential $sqlCredential | New-DbCommand $query | Enter-DbTransaction -PassThru | Get-DbData -OutputAs DataTable
            $dt.Rows.Count | Should -Be 1

            $dt.Rows.Delete()
            $dt.Alter() | Should -Be 1

            $dt.Rows.Count | Should -Be 0

            $query = "SELECT * FROM dbo.MyData ORDER BY SSN;"
            $dt = New-DbConnection $ServerInstance -SqlCredential $sqlCredential | New-DbCommand $query | Enter-DbTransaction -PassThru | Get-DbData -OutputAs DataTable
            $dt | Should -Not -BeNullOrEmpty
            #>
        }
        It "commits" {

        }
    }

    Context "Bulk inserts" {

    }
}
