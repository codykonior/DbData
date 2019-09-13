<#

.SYNOPSIS
Create a SQL Server connection or connection string.

.DESCRIPTION
This is a safe way of building a connection string without joining them together manually.

.PARAMETER DataSource
Server name and instance.

.PARAMETER InitialCatalog
Database name. If not specified the login's default database is used. It's strongly recommended to always specify master so that connection pooling can be used.

.PARAMETER AsString
Return a connection string instead of a connection object. This cannot be used with SqlCredential.

.PARAMETER UserID
For SQL Authentication. Otherwise Integrated Security is used.

.PARAMETER Password
For SQL Authentication. Otherwise Integrated Security is used.

.PARAMETER SqlCredential
As of .NET Framework 4.5 the preferred method of passing SQL Authentication credentials is using System.Data.SqlClient.SqlCredential. PSCredentials will be converted to this automatically. This is added to the connection object, and so, cannot be used if you are requesting only a connection string.

.PARAMETER IntegratedSecurity
Enabled automatically if no UserID, Password, or SqlCredential is passed in. However you can explicitly set it also.

.PARAMETER ApplicationName
Free text recorded by SQL Server so that DBAs can identify what a session is being used for. Also useful for connection pooling.

.PARAMETER ApplicationIntent
ReadOnly or ReadWrite for AlwaysOn Availability Groups.

.PARAMETER WorkstationID
By default this is populated with $env:COMPUTERNAME by the .NET Framework, however, it can be spoofed here.

.PARAMETER ConnectTimeout
The number of seconds to wait before timing out the connection.

.PARAMETER MultipleActiveResultSets
A switch to enable this functionality which is required for Entity Framework (but not LINQ to SQL).

.PARAMETER MultiSubnetFailover
For High Availability scenarios connections will be concurrently attempted on multiple IPs concurrently (but only for Availability Group listeners and Failover Clusters on SQL 2012+). This is not required as of .NET Framework 4.6.1 as it's enabled automatically.

.PARAMETER ConnectionString
A connection string to start off with.

.PARAMETER Open
Open the connection for you before returning it. Make sure you close it at some stage.

.INPUTS
None. You cannot pipe objects.

.OUTPUTS
A connection object or string.

.EXAMPLE
$serverInstance = ".\SQL2016"
New-DbConnection $serverInstance master

Connect to a local server. Returns the connection object.

.EXAMPLE
$serverInstance = ".\SQL2016"
New-DbConnection $serverInstance master some_user unsafe_password

Connect to a server with a username and password. There are better ways to do this. Returns:

Data Source=.\SQL2016;Initial Catalog=master;User ID=some_user;Password=unsafe_password

.NOTES
For descriptions of other parameter values please check MSDN.

.LINK
https://msdn.microsoft.com/en-us/library/system.data.sqlclient.sqlconnectionstringbuilder%28v=vs.110%29.aspx?f=255&MSPPError=-2147217396

#>

function New-DbConnection {
    [CmdletBinding()]
    [System.Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidUsingUserNameAndPassWordParams', '')]
    [System.Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSProvideDefaultParameterValue', 'UserName')]
    [System.Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidUsingPlainTextForPassword', 'Password')]
    [System.Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidUsingPlainTextForPassword', 'SqlCredential')]
    [System.Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSAvoidUsingConvertToSecureStringWithPlainText", "")]
    [System.Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSUseShouldProcessForStateChangingFunctions", "")]
    param (
        $ApplicationIntent,
        $ApplicationName,
        $AsynchronousProcessing,
        $AttachDBFilename,
        $Authentication,
        $BrowsableConnectionString,
        $ColumnEncryptionSetting,
        $ConnectionReset,
        $ConnectRetryCount,
        $ConnectRetryInterval,
        $ConnectTimeout,
        $ContextConnection,
        $CurrentLanguage,
        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName, Position = 0)]
        [ValidateNotNullOrEmpty()]
        [Alias("SqlServerName")]
        [Alias("ServerInstance")]
        [string] $DataSource,
        $Encrypt,
        $Enlist,
        $FailoverPartner,
        [Parameter(ValueFromPipelineByPropertyName, Position = 1)]
        [Alias("Database")]
        [Alias("DatabaseName")]
        [string] $InitialCatalog,
        $IntegratedSecurity,
        $LoadBalanceTimeout,
        $MaxPoolSize,
        $MinPoolSize,
        $MultipleActiveResultSets,
        $MultiSubnetFailover,
        $NetworkLibrary,
        $PacketSize,
        [Parameter(Position = 3)]
        [string] $Password,
        $PersistSecurityInfo,
        $Pooling,
        $Replication,
        $TransactionBinding,
        $TransparentNetworkIPResolution,
        $TrustServerCertificate,
        $TypeSystemVersion,
        [Parameter(Position = 2)]
        [Alias("UserName")]
        [string] $UserID,
        $UserInstance,
        [Alias("ComputerName")]
        [Alias("HostName")]
        [string] $WorkstationID,
        $ConnectionString,

        [Alias("Credential")]
        $SqlCredential,
        [switch] $AsString,
        [switch] $Open,
        [switch] $FireInfoMessageEventOnUserErrors
    )

    begin {
    }

    process {
        $connectionBuilder = New-Object System.Data.SqlClient.SqlConnectionStringBuilder($ConnectionString)

        if ($PSBoundParameters.ContainsKey("DataSource")) {
            $connectionBuilder["Data Source"] = $DataSource
        }
        if ($PSBoundParameters.ContainsKey("FailoverPartner")) {
            $connectionBuilder["Failover Partner"] = $FailoverPartner
        }
        if ($PSBoundParameters.ContainsKey("AttachDbFilename")) {
            $connectionBuilder["AttachDbFilename"] = $AttachDbFilename
        }
        if ($PSBoundParameters.ContainsKey("InitialCatalog")) {
            $connectionBuilder["Initial Catalog"] = $InitialCatalog
        }
        if ($PSBoundParameters.ContainsKey("IntegratedSecurity")) {
            $connectionBuilder["Integrated Security"] = $IntegratedSecurity
        }
        if ($PSBoundParameters.ContainsKey("PersistSecurityInfo")) {
            $connectionBuilder["Persist Security Info"] = $PersistSecurityInfo
        }
        if ($PSBoundParameters.ContainsKey("Enlist")) {
            $connectionBuilder["Enlist"] = $Enlist
        }
        if ($PSBoundParameters.ContainsKey("Pooling")) {
            $connectionBuilder["Pooling"] = $Pooling
        }
        if ($PSBoundParameters.ContainsKey("MinPoolSize")) {
            $connectionBuilder["Min Pool Size"] = $MinPoolSize
        }
        if ($PSBoundParameters.ContainsKey("MaxPoolSize")) {
            $connectionBuilder["Max Pool Size"] = $MaxPoolSize
        }
        if ($PSBoundParameters.ContainsKey("AsynchronousProcessing")) {
            $connectionBuilder["Asynchronous Processing"] = $AsynchronousProcessing
        }
        if ($PSBoundParameters.ContainsKey("ConnectionReset")) {
            $connectionBuilder["Connection Reset"] = $ConnectionReset
        }
        if ($PSBoundParameters.ContainsKey("MultipleActiveResultSets")) {
            $connectionBuilder["MultipleActiveResultSets"] = $MultipleActiveResultSets
        }
        if ($PSBoundParameters.ContainsKey("Replication")) {
            $connectionBuilder["Replication"] = $Replication
        }
        if ($PSBoundParameters.ContainsKey("ConnectTimeout")) {
            $connectionBuilder["Connect Timeout"] = $ConnectTimeout
        }
        if ($PSBoundParameters.ContainsKey("Encrypt")) {
            $connectionBuilder["Encrypt"] = $Encrypt
        }
        if ($PSBoundParameters.ContainsKey("TrustServerCertificate")) {
            $connectionBuilder["TrustServerCertificate"] = $TrustServerCertificate
        }
        if ($PSBoundParameters.ContainsKey("LoadBalanceTimeout")) {
            $connectionBuilder["Load Balance Timeout"] = $LoadBalanceTimeout
        }
        if ($PSBoundParameters.ContainsKey("NetworkLibrary")) {
            $connectionBuilder["Network Library"] = $NetworkLibrary
        }
        if ($PSBoundParameters.ContainsKey("PacketSize")) {
            $connectionBuilder["Packet Size"] = $PacketSize
        }
        if ($PSBoundParameters.ContainsKey("TypeSystemVersion")) {
            $connectionBuilder["Type System Version"] = $TypeSystemVersion
        }
        if ($PSBoundParameters.ContainsKey("Authentication")) {
            $connectionBuilder["Authentication"] = $Authentication
        }
        if ($PSBoundParameters.ContainsKey("ApplicationName")) {
            $connectionBuilder["Application Name"] = $ApplicationName
        }
        if ($PSBoundParameters.ContainsKey("CurrentLanguage")) {
            $connectionBuilder["Current Language"] = $CurrentLanguage
        }
        if ($PSBoundParameters.ContainsKey("WorkstationID")) {
            $connectionBuilder["Workstation ID"] = $WorkstationID
        }
        if ($PSBoundParameters.ContainsKey("UserInstance")) {
            $connectionBuilder["User Instance"] = $UserInstance
        }
        if ($PSBoundParameters.ContainsKey("ContextConnection")) {
            $connectionBuilder["Context Connection"] = $ContextConnection
        }
        if ($PSBoundParameters.ContainsKey("TransactionBinding")) {
            $connectionBuilder["Transaction Binding"] = $TransactionBinding
        }
        if ($PSBoundParameters.ContainsKey("ApplicationIntent")) {
            $connectionBuilder["ApplicationIntent"] = $ApplicationIntent
        }
        if ($PSBoundParameters.ContainsKey("MultiSubnetFailover")) {
            $connectionBuilder["MultiSubnetFailover"] = $MultiSubnetFailover
        }
        if ($PSBoundParameters.ContainsKey("TransparentNetworkIPResolution")) {
            $connectionBuilder["TransparentNetworkIPResolution"] = $TransparentNetworkIPResolution
        }
        if ($PSBoundParameters.ContainsKey("ConnectRetryCount")) {
            $connectionBuilder["ConnectRetryCount"] = $ConnectRetryCount
        }
        if ($PSBoundParameters.ContainsKey("ConnectRetryInterval")) {
            $connectionBuilder["ConnectRetryInterval"] = $ConnectRetryInterval
        }
        if ($PSBoundParameters.ContainsKey("ColumnEncryptionSetting")) {
            $connectionBuilder["Column Encryption Setting"] = $ColumnEncryptionSetting
        }

        if (-not ($UserID -or $SqlCredential)) {
            $connectionBuilder["Integrated Security"] = $true
        }

        if ($AsString) {
            # If we're returning a string we have no choice but to give input UserID and Password
            if ($PSBoundParameters.ContainsKey("UserID")) {
                $connectionBuilder["User ID"] = $UserID
            }
            if ($PSBoundParameters.ContainsKey("Password")) {
                $connectionBuilder["Password"] = $Password
            }

            $connectionBuilder.ConnectionString
        } else {
            $sqlConnection = New-Object System.Data.SqlClient.SqlConnection($connectionBuilder.ConnectionString)
            Add-DbOpen $sqlConnection

            if ($PSBoundParameters.ContainsKey("SqlCredential")) {
                # Convert Credential to SqlCredential
                if ($SqlCredential -is [System.Management.Automation.PSCredential]) {
                    $SqlCredential.Password.MakeReadOnly()
                    $SqlCredential = New-Object System.Data.SqlClient.SqlCredential($SqlCredential.UserName, $SqlCredential.Password)
                }
                $SqlConnection.Credential = $SqlCredential
            } elseif ($PSBoundParameters.ContainsKey("UserID")) {
                if ([string]::IsNullOrEmpty($Password)) {
                    # This allows a blank password...
                    $securePassword = New-Object System.Security.SecureString
                } else {
                    $securePassword = ConvertTo-SecureString $Password -AsPlainText -Force
                }
                $securePassword.MakeReadOnly()
                $SqlCredential = New-Object System.Data.SqlClient.SqlCredential($UserID, $securePassword)
                $SqlConnection.Credential = $SqlCredential
            }

            if ($PSBoundParameters.ContainsKey("FireInfoMessageEventOnUserErrors")) {
                $sqlConnection.FireInfoMessageEventOnUserErrors = $FireInfoMessageEventOnUserErrors
            }

            if ($Open) {
                $sqlConnection.Open()
            }
            $sqlConnection
        }
    }

    end {
    }
}
