<#

.SYNOPSIS

.DESCRIPTION

.PARAMETER InitialCatalog
The name of the initial catalog or database in the data source.

.PARAMETER ConnectionString
A starting connection string.

.PARAMETER ApplicationName
The name of the application.

.PARAMETER UserID
Indicates the user ID to be used when connecting to the data source.

.PARAMETER Pooling
When true, the connection object is drawn from the appropriate pool, or if necessary, is created and added to the appropriate pool.

.PARAMETER LoadBalanceTimeout
The minimum amount of time (in seconds) for this connection to live in the pool before being destroyed.

.PARAMETER MultipleActiveResultSets
When true, multiple result sets can be returned and read from one connection.

.PARAMETER MultiSubnetFailover
If your application is connecting to a high-availability, disaster recovery (AlwaysOn) availability group (AG) on different subnets, MultiSubnetFailover=Yes configures SqlConnection to provide faster detection of and connection to the (currently) active server.

.PARAMETER DataSource
Indicates the name of the data source to connect to.

.PARAMETER PoolBlockingPeriod
Defines the blocking period behavior for a connection pool.

.PARAMETER FailoverPartner
The name or network address of the instance of SQL Server that acts as a failover partner.

.PARAMETER CurrentLanguage
The SQL Server Language record name.

.PARAMETER ServerSPN
The service principal name (SPN) of the server.

.PARAMETER ServerCertificate
The path to a certificate file to match against the SQL Server TLS/SSL certificate.

.PARAMETER IPAddressPreference
Specifies an IP address preference when connecting to SQL instances.

.PARAMETER HostNameInCertificate
The hostname to be expected in the server's certificate when encryption is negotiated, if it's different from the default value derived from Addr/Address/Server.

.PARAMETER Password
Indicates the password to be used when connecting to the data source.

.PARAMETER CommandTimeout
Time to wait for command to execute.

.PARAMETER AttachDBFilename
The name of the primary file, including the full path name, of an attachable database.

.PARAMETER MaxPoolSize
The maximum number of connections allowed in the pool.

.PARAMETER IntegratedSecurity
Whether the connection is to be a secure connection or not.

.PARAMETER ConnectTimeout
The length of time (in seconds) to wait for a connection to the server before terminating the attempt and generating an error.

.PARAMETER ConnectRetryInterval
Delay between attempts to restore connection.

.PARAMETER Enlist
Sessions in a Component Services (or MTS, if you are using Microsoft Windows NT) environment should automatically be enlisted in a global transaction where required.

.PARAMETER TransactionBinding
Indicates binding behavior of connection to a System.Transactions Transaction when enlisted.

.PARAMETER PersistSecurityInfo
When false, security-sensitive information, such as the password, is not returned as part of the connection if the connection is open or has ever been in an open state.

.PARAMETER UserInstance
Indicates whether the connection will be re-directed to connect to an instance of SQL Server running under the user's account.

.PARAMETER Authentication
Specifies the method of authenticating with SQL Server.

.PARAMETER PacketSize
Size in bytes of the network packets used to communicate with an instance of SQL Server.

.PARAMETER Encrypt
When true, SQL Server uses SSL encryption for all data sent between the client and server if the server has a certificate installed.

.PARAMETER Replication
Used by SQL Server in Replication.

.PARAMETER MinPoolSize
The minimum number of connections allowed in the pool.

.PARAMETER ConnectRetryCount
Number of attempts to restore connection.

.PARAMETER ApplicationIntent
Declares the application workload type when connecting to a server.

.PARAMETER TrustServerCertificate
When true (and encrypt=true), SQL Server uses SSL encryption for all data sent between the client and server without validating the server certificate.

.PARAMETER WorkstationID
The name of the workstation connecting to SQL Server.

.PARAMETER FailoverPartnerSPN
The service principal name (SPN) of the failover partner.

.PARAMETER ColumnEncryptionSetting
Default column encryption setting for all the commands on the connection.

.PARAMETER EnclaveAttestationUrl
Specifies an endpoint of an enclave attestation service, which will be used to verify whether the enclave, configured in the SQL Server instance for computations on database columns encrypted using Always Encrypted, is valid and secure.

.PARAMETER AttestationProtocol
Specifies an attestation protocol for its corresponding enclave attestation service.

.PARAMETER TypeSystemVersion
Indicates which server type system the provider will expose through the DataReader.

---

.PARAMETER RetryLogicProvider


.PARAMETER StatisticsEnabled


.PARAMETER AccessToken


.PARAMETER Credential


.PARAMETER FireInfoMessageEventOnUserErrors
Event.

.PARAMETER InfoMessage
Event.

.PARAMETER StateChange
Event.

.PARAMETER Callback

.INPUTS

.OUTPUTS

.EXAMPLE

#>
function New-DbConnection {
    [CmdletBinding()]
    param (
        [Parameter(ValueFromPipelineByPropertyName)]
        [Alias("ServerName")]
        [Alias("ServerInstance")]
        [Alias("FullyQualifiedDomainName")]
        [string] $DataSource,
        [Parameter(ValueFromPipelineByPropertyName)]
        [Alias("DatabaseName")]
        [string] $InitialCatalog,
        [Parameter(ValueFromPipelineByPropertyName)]
        [string] $ConnectionString,
        [string] $ApplicationName,
        [string] $UserID,
        [bool] $Pooling,
        [int] $LoadBalanceTimeout,
        [bool] $MultipleActiveResultSets,
        [bool] $MultiSubnetFailover,
        [Microsoft.Data.SqlClient.PoolBlockingPeriod] $PoolBlockingPeriod,
        [string] $FailoverPartner,
        [string] $CurrentLanguage,
        [string] $ServerSPN,
        [string] $ServerCertificate,
        [Microsoft.Data.SqlClient.SqlConnectionIPAddressPreference] $IPAddressPreference,
        [string] $HostNameInCertificate,
        [string] $Password,
        [int] $CommandTimeout,
        [string] $AttachDBFilename,
        [int] $MaxPoolSize,
        [bool] $IntegratedSecurity,
        [int] $ConnectTimeout,
        [int] $ConnectRetryInterval,
        [bool] $Enlist,
        [string] $TransactionBinding,
        [bool] $PersistSecurityInfo,
        [bool] $UserInstance,
        [Microsoft.Data.SqlClient.SqlAuthenticationMethod] $Authentication,
        [int] $PacketSize,
        [Microsoft.Data.SqlClient.SqlConnectionEncryptOption] $Encrypt,
        [bool] $Replication,
        [int] $MinPoolSize,
        [int] $ConnectRetryCount,
        [Microsoft.Data.SqlClient.ApplicationIntent] $ApplicationIntent,
        [bool] $TrustServerCertificate,
        [string] $WorkstationID,
        [string] $FailoverPartnerSPN,
        [Microsoft.Data.SqlClient.SqlConnectionColumnEncryptionSetting] $ColumnEncryptionSetting,
        [string] $EnclaveAttestationUrl,
        [Microsoft.Data.SqlClient.SqlConnectionAttestationProtocol] $AttestationProtocol,
        [string] $TypeSystemVersion,

        [Parameter(ValueFromPipelineByPropertyName)]
        [Microsoft.Data.SqlClient.SqlRetryLogicBaseProvider] $RetryLogicProvider,
        [Parameter(ValueFromPipelineByPropertyName)]
        [bool] $StatisticsEnabled,
        [Parameter(ValueFromPipelineByPropertyName)]
        [string] $AccessToken,
        [Parameter(ValueFromPipelineByPropertyName)]
        [Microsoft.Data.SqlClient.SqlCredential] $Credential,
        [Parameter(ValueFromPipelineByPropertyName)]
        [bool] $FireInfoMessageEventOnUserErrors,
        [Parameter(ValueFromPipelineByPropertyName)]
        [System.Management.Automation.PSEvent] $InfoMessage,
        [Parameter(ValueFromPipelineByPropertyName)]
        [System.Management.Automation.PSEvent] $StateChange,

        $Callback
    )

    begin {
    }

    process {
        $connectionStringBuilder = New-Object Microsoft.Data.SqlClient.SqlConnectionStringBuilder($ConnectionString)
        if ($PSBoundParameters.ContainsKey("InitialCatalog")) { $connectionStringBuilder."Initial Catalog" = $InitialCatalog }
        if ($PSBoundParameters.ContainsKey("ApplicationName")) { $connectionStringBuilder."Application Name" = $ApplicationName }
        if ($PSBoundParameters.ContainsKey("UserID")) { $connectionStringBuilder."User ID" = $UserID }
        if ($PSBoundParameters.ContainsKey("Pooling")) { $connectionStringBuilder."Pooling" = $Pooling }
        if ($PSBoundParameters.ContainsKey("LoadBalanceTimeout")) { $connectionStringBuilder."Load Balance Timeout" = $LoadBalanceTimeout }
        if ($PSBoundParameters.ContainsKey("MultipleActiveResultSets")) { $connectionStringBuilder."Multiple Active Result Sets" = $MultipleActiveResultSets }
        if ($PSBoundParameters.ContainsKey("MultiSubnetFailover")) { $connectionStringBuilder."Multi Subnet Failover" = $MultiSubnetFailover }
        if ($PSBoundParameters.ContainsKey("DataSource")) { $connectionStringBuilder."Data Source" = $DataSource }
        if ($PSBoundParameters.ContainsKey("PoolBlockingPeriod")) { $connectionStringBuilder."Pool Blocking Period" = $PoolBlockingPeriod }
        if ($PSBoundParameters.ContainsKey("FailoverPartner")) { $connectionStringBuilder."Failover Partner" = $FailoverPartner }
        if ($PSBoundParameters.ContainsKey("CurrentLanguage")) { $connectionStringBuilder."Current Language" = $CurrentLanguage }
        if ($PSBoundParameters.ContainsKey("ServerSPN")) { $connectionStringBuilder."Server SPN" = $ServerSPN }
        if ($PSBoundParameters.ContainsKey("ServerCertificate")) { $connectionStringBuilder."Server Certificate" = $ServerCertificate }
        if ($PSBoundParameters.ContainsKey("IPAddressPreference")) { $connectionStringBuilder."IP Address Preference" = $IPAddressPreference }
        if ($PSBoundParameters.ContainsKey("HostNameInCertificate")) { $connectionStringBuilder."Host Name In Certificate" = $HostNameInCertificate }
        if ($PSBoundParameters.ContainsKey("Password")) { $connectionStringBuilder."Password" = $Password }
        if ($PSBoundParameters.ContainsKey("CommandTimeout")) { $connectionStringBuilder."Command Timeout" = $CommandTimeout }
        if ($PSBoundParameters.ContainsKey("AttachDBFilename")) { $connectionStringBuilder."AttachDbFilename" = $AttachDBFilename }
        if ($PSBoundParameters.ContainsKey("MaxPoolSize")) { $connectionStringBuilder."Max Pool Size" = $MaxPoolSize }
        if ($PSBoundParameters.ContainsKey("IntegratedSecurity")) { $connectionStringBuilder."Integrated Security" = $IntegratedSecurity }
        if ($PSBoundParameters.ContainsKey("ConnectTimeout")) { $connectionStringBuilder."Connect Timeout" = $ConnectTimeout }
        if ($PSBoundParameters.ContainsKey("ConnectRetryInterval")) { $connectionStringBuilder."Connect Retry Interval" = $ConnectRetryInterval }
        if ($PSBoundParameters.ContainsKey("Enlist")) { $connectionStringBuilder."Enlist" = $Enlist }
        if ($PSBoundParameters.ContainsKey("TransactionBinding")) { $connectionStringBuilder."Transaction Binding" = $TransactionBinding }
        if ($PSBoundParameters.ContainsKey("PersistSecurityInfo")) { $connectionStringBuilder."Persist Security Info" = $PersistSecurityInfo }
        if ($PSBoundParameters.ContainsKey("UserInstance")) { $connectionStringBuilder."User Instance" = $UserInstance }
        if ($PSBoundParameters.ContainsKey("Authentication")) { $connectionStringBuilder."Authentication" = $Authentication }
        if ($PSBoundParameters.ContainsKey("PacketSize")) { $connectionStringBuilder."Packet Size" = $PacketSize }
        if ($PSBoundParameters.ContainsKey("Encrypt")) { $connectionStringBuilder."Encrypt" = $Encrypt }
        if ($PSBoundParameters.ContainsKey("Replication")) { $connectionStringBuilder."Replication" = $Replication }
        if ($PSBoundParameters.ContainsKey("MinPoolSize")) { $connectionStringBuilder."Min Pool Size" = $MinPoolSize }
        if ($PSBoundParameters.ContainsKey("ConnectRetryCount")) { $connectionStringBuilder."Connect Retry Count" = $ConnectRetryCount }
        if ($PSBoundParameters.ContainsKey("ApplicationIntent")) { $connectionStringBuilder."Application Intent" = $ApplicationIntent }
        if ($PSBoundParameters.ContainsKey("TrustServerCertificate")) { $connectionStringBuilder."Trust Server Certificate" = $TrustServerCertificate }
        if ($PSBoundParameters.ContainsKey("WorkstationID")) { $connectionStringBuilder."Workstation ID" = $WorkstationID }
        if ($PSBoundParameters.ContainsKey("FailoverPartnerSPN")) { $connectionStringBuilder."Failover Partner SPN" = $FailoverPartnerSPN }
        if ($PSBoundParameters.ContainsKey("ColumnEncryptionSetting")) { $connectionStringBuilder."Column Encryption Setting" = $ColumnEncryptionSetting }
        if ($PSBoundParameters.ContainsKey("EnclaveAttestationUrl")) { $connectionStringBuilder."Enclave Attestation Url" = $EnclaveAttestationUrl }
        if ($PSBoundParameters.ContainsKey("AttestationProtocol")) { $connectionStringBuilder."Attestation Protocol" = $AttestationProtocol }
        if ($PSBoundParameters.ContainsKey("TypeSystemVersion")) { $connectionStringBuilder."Type System Version" = $TypeSystemVersion }

        if ($Callback) {
            &$Callback -ConnectionStringBuilder $connectionStringBuilder
        }

        $connection = New-Object Microsoft.Data.SqlClient.SqlConnection($connectionStringBuilder.ToString())
        $connection | Add-Member -MemberType NoteProperty -Name ConnectionStringBuilder -Value $connectionStringBuilder

        if ($PSBoundParameters.ContainsKey("RetryLogicProvider")) { $connection.RetryLogicProvider = $RetryLogicProvider }
        if ($PSBoundParameters.ContainsKey("StatisticsEnabled")) { $connection.StatisticsEnabled = $StatisticsEnabled }
        if ($PSBoundParameters.ContainsKey("ConnectionString")) { $connection.ConnectionString = $ConnectionString }
        if ($PSBoundParameters.ContainsKey("AccessToken")) { $connection.AccessToken = $AccessToken }
        if ($PSBoundParameters.ContainsKey("Credential")) { $connection.Credential = $Credential }
        if ($PSBoundParameters.ContainsKey("FireInfoMessageEventOnUserErrors")) { $connection.FireInfoMessageEventOnUserErrors = $FireInfoMessageEventOnUserErrors }
        if ($PSBoundParameters.ContainsKey("InfoMessage")) { $connection.InfoMessage = $InfoMessage }
        if ($PSBoundParameters.ContainsKey("StateChange")) { $connection.StateChange = $StateChange }

        if ($Callback) {
            &$Callback -Connection $connection
        }

        $connection
    }

    end {

    }
}
