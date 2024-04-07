<#
.SYNOPSIS
    Get the AAGUIDs of all passkeys that are registered in the tenant.

.DESCRIPTION
    Get the AAGUIDs of all passkeys that are registered in the tenant.

.EXAMPLE
    # Get-PasskeyDeviceBoundAAGUID

    This example gets the AAGUIDs of all passkeys that are registered in the tenant.

.NOTES
    Read more about the Entra ID passkey preview at https://cloudbrothers.info/passkeyPreview
#>
function Get-PasskeyDeviceBoundAAGUID {
    [CmdletBinding()]
    param ()

    $ReturnValue = [System.Collections.ArrayList]::new()

    Write-Verbose "Getting AAGUIDs of all passkeys that are registered in the tenant..."

    $NextUri = "https://graph.microsoft.com/beta/reports/authenticationMethods/userRegistrationDetails?`$filter=methodsRegistered/any(x:x eq 'passKeyDeviceBound')"
    try {
        do {
            Write-Progress "Getting AAGUIDs of all passkeys that are registered in the tenant..." -PercentComplete -1
            $Result = Invoke-MgGraphRequest -Uri $NextUri -Verbose:$false
            $NextUri = $Result['@odata.nextLink']
            $Result['value']  | ForEach-Object {
                $ReturnValue.Add($_) | Out-Null 
            }
        } while (-not [string]::IsNullOrWhiteSpace($NextUri) )
    } catch {
        if ($_ -match "Authentication_RequestFromNonPremiumTenantOrB2CTenant") {
            Write-Warning "The Microsoft Graph API endpoint 'reports/authenticationMethods/userRegistrationDetails' requires an Entra ID Premium P1 or P2 license."
            Write-Warning "Fallback to get a list of all users in the tenant and enumerate their FIDO2 methods instead. This may be very slow."
        } else {
            throw "Failed to get current list of passkey device-bound users. Error: $_"
        }
    }

    $NextUri = "https://graph.microsoft.com/beta/users"
    try {
        do {
            Write-Progress "Getting AAGUIDs of all passkeys that are registered in the tenant by enumerating all users (maybe very slow)..." -PercentComplete -1
            $Result = Invoke-MgGraphRequest -Uri $NextUri -Verbose:$false
            $NextUri = $Result['@odata.nextLink']
            $Result['value']  | ForEach-Object {
                $ReturnValue.Add($_) | Out-Null 
            }
        } while (-not [string]::IsNullOrWhiteSpace($NextUri) )
    } catch {
        throw "Failed to get current list of passkey device-bound users. Error: $_"
    }

    Write-Verbose "Found $($ReturnValue.Count) passkey device-bound users"

    $PassKeyDeviceBoundUsers = $ReturnValue |  Select-Object id, userPrincipalName
    $PassKeyDeviceBoundAAGUIDs = [System.Collections.ArrayList]::new()

    try {
        foreach ( $User in $PassKeyDeviceBoundUsers ) {
            $CurrentMethods = Invoke-MgGraphRequest -Uri "https://graph.microsoft.com/v1.0/users/$($User.id)/authentication/fido2Methods" -Verbose:$false | Select-Object -ExpandProperty value
            $CurrentMethods | ForEach-Object {
                $PassKeyDeviceBoundAAGUIDs.Add($_) | Out-Null
            }
        }
    } catch {
        throw "Failed to get current list of passkey device-bound users. Error: $_"
    }

    Write-Verbose "Found $($PassKeyDeviceBoundAAGUIDs | Select-Object AAGuid -Unique | Measure-Object | Select-Object -ExpandProperty Count ) unique AAGUIDs"

    $PassKeyDeviceBoundAAGUIDs | Select-Object aaGuid, Model -Unique | Sort-Object Model
}
