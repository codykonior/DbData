<#

.SYNOPSIS
Create an SQL Server connection using the underlying .NET builder class.

.DESCRIPTION
This is a safer way of getting a connection string than joining them together manually.

There are a lot more options than provided here, it's just what's common.

.PARAMETER ServerInstance
Specified as ServerName\Instance.

.PARAMETER DatabaseName
The database name if required. It defaults to no database but it's strongly recommended you use something (at least master) so that connection pooling can be used automatically.

.PARAMETER UserName
If specified SQL Authentication will be used.

.PARAMETER Password
If specified SQL Authentication will be used.

.PARAMETER ApplicationName
Free text recorded by SQL Server so that Database Administrators can identify what a session is being used for. Also useful for connection pooling.

.PARAMETER ApplicationIntent
ReadOnly or ReadWrite for AlwaysOn Availability Groups.

.PARAMETER HostName
Populated with the computer name being connected from so that Database Administrators can identify where a session comes from, but can be masked.

.PARAMETER ConnectTimeout
The number of seconds to wait before timing out the connection.

.PARAMETER MultipleActiveResultSets
A switch to enable this functionality which is required for Entity Framework (but not LINQ to SQL).

.PARAMETER MultiSubnetFailover
For High Availability scenarios connections will be concurrently attempted on multiple IPs concurrently.

.INPUTS
None. You cannot pipe objects.

.OUTPUTS
A connection string.

.EXAMPLE
$serverInstance = ".\SQL2016"
New-DbConnection $serverInstance master

Connect to a local server. Returns:

# Data Source=.\SQL2016;Initial Catalog=master;Integrated Security=True

.EXAMPLE
$serverInstance = ".\SQL2016"
New-DbConnection $serverInstance master some_user unsafe_password

Connect to a server with a username and password. There are better ways to do this.

# Data Source=.\SQL2016;Initial Catalog=master;Integrated Security=False;User ID=some_user;Password=unsafe_password

#>

function New-DbConnection {
	[CmdletBinding()]
	param (
		[Parameter(Mandatory = $true, ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true)]
        [ValidateNotNullOrEmpty()]
        [Alias("SqlServerName")]
		[string] $ServerInstance,
        
        $Database,

		$UserName,
		$Password,
        $SqlCredential,

		$ApplicationName,
		[System.Data.SqlClient.ApplicationIntent] $ApplicationIntent,
		$HostName,
		
        [switch] $Pooling,
        [int] $ConnectTimeout,
        [switch] $MultipleActiveResultSets,
		[switch] $MultiSubnetFailover,

        [switch] $AsString = $true
	)

    begin {
    }

    process {
	    $connectionBuilder = New-Object System.Data.SqlClient.SqlConnectionStringBuilder

	    $connectionBuilder."Data Source" = $ServerInstance
            if ($Database) {
    	        $connectionBuilder."Initial Catalog" = $Database
	    }
        if ($UserName){
		    $connectionBuilder."Integrated Security" = $false

            $connectionBuilder."User ID" = $UserName
    		$connectionBuilder."Password" = $Password
	    } elseif ($SqlCredential) {
		    $connectionBuilder."Integrated Security" = $false
        } else {
		    $connectionBuilder."Integrated Security" = $true
	    }
	    if ($ApplicationIntent) {
		    $connectionBuilder."ApplicationIntent" = $ApplicationIntent
	    }
        if ($ConnectTimeout) {
            $connectionBuilder."Connect Timeout" = $ConnectTimeout
        }
	    if ($ApplicationName) {
		    $connectionBuilder."Application Name" = $ApplicationName
	    }
	    if ($HostName) {
		    $connectionBuilder."Workstation Id" = $HostName
	    }
        if ($Pooling) {
            $connectionBuilder."Pooling" = $Pooling
        }
	    if ($MultipleActiveResultSets) {
		    $connectionBuilder."MultipleActiveResultSets" = $MultipleActiveResultSets
	    } 
	    if ($MultiSubnetFailover) {
		    $connectionBuilder."MultiSubnetFailover" = $MultiSubnetFailover
	    } 

        if ($AsString) {
            $connectionBuilder.ConnectionString
        } else {
            $sqlConnection = New-Object System.Data.SqlClient.SqlConnection($connectionBuilder.ConnectionString)
            if ($sqlCredential) {
                $sqlConnection.SqlCredential = $SqlCredential
            }
            $sqlConnection
        }
    } 

    end {
    }
} 
