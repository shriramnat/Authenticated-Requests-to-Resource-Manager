#============================= REPLACE THIS ======================================================

$armEndpoint = " https://adminmanagement.redmond.azurestack.corp.microsoft.com"

#==================================================================================================

#Gets a Token for Resource Manager
function Get-AccessToken {
    param(
                            $TenantId, 
                            $ResourceId, 
                            $LoginEndpoint = "https://login.microsoftonline.com"
    ) 

    $clientId = "1950a258-227b-4e31-a9cf-717495945fc2"
    $redirectUri = New-Object system.uri("urn:ietf:wg:oauth:2.0:oob")


    #ADAL Prompt Behavior Configuration (Always, Auto, Never)
    $promptBehavior = [Microsoft.IdentityModel.Clients.ActiveDirectory.PromptBehavior]::Auto

    # Get an Access Token with ADAL
    $authContext = New-Object Microsoft.IdentityModel.Clients.ActiveDirectory.AuthenticationContext ("{0}/{1}" -f $LoginEndpoint,$tenantId)
    $authenticationResult = $authContext.AcquireToken($resourceId, $clientID, $redirectUri, $promptBehavior) 
    
    return $authenticationResult.AccessToken
}

# Generic method to call an API with a Bearer token
function Send-WebRequest {
    param(
    [string] $Uri,
    [string] $Token
    )

    $request = @{
        Uri = $Uri
        Method = "GET"
        Headers = @{ "Authorization" = "Bearer " + $Token }
        ContentType = "application/json"
    }

    return (Invoke-RestMethod @request).value

}


#============= OPTIONAL: replace this if you're using the script for anything other than selfhost ======
$tenantName = "masselfhost.onmicrosoft.com"
$subscriptionName = "Default Provider Subscription"
#=======================================================================================================


# Get Resource Manager Token for $armEndpoint in the tenant $tenantName
$authToken = Get-AccessToken -TenantId $(irm $("https://login.windows.net/{0}/.well-known/openid-configuration" -f $tenantName.TrimEnd('/'))).issuer.TrimEnd('/').Split('/')[-1] `
    -ResourceId $(irm $("{0}/metadata/endpoints?api-version=2017-06-01" -f $armEndpoint)).authentication.audiences[0]

#Get Subscription Id for $subscriptionName
$defaultProviderSubscriptionId = (Send-WebRequest `
                                        -Uri ("{0}/subscriptions?api-version=2014-04-01-preview" -f $armEndpoint) `
                                        -Token $authToken | Where-Object {$_.displayName -eq $subscriptionName}).subscriptionId

# Get User Subscriptions
$userSubscriptions = Send-WebRequest `
                            -Uri ("{0}/subscriptions/{1}/providers/Microsoft.Subscriptions.Admin/subscriptions?api-version=2015-11-01" -f $armEndpoint, $defaultProviderSubscriptionId) `
                            -Token $authToken
# Export the data to CSV
$userSubscriptions.value | select Owner, displayName, subscriptionId | Export-Csv -Path ("{0}\UserSubscriptions.csv" -f [environment]::getfolderpath("mydocuments")) -NoTypeInformation