# Bicep Configuration

**IMPORTANT**: Before deploying, update `bicepconfig.json` with your actual Azure Container Registry name.

## Setup

1. Open `bicepconfig.json`
2. Replace `contosoplatform.azurecr.io` with your actual ACR name
3. Example:
   ```json
   {
     "moduleAliases": {
       "br": {
         "ContosoACR": {
           "registry": "myacr.azurecr.io"
         }
       }
     }
   }
   ```

## For Development

To test locally without ACR, edit `main.bicep`:

1. Comment out the ACR reference
2. Uncomment the local file reference

```bicep
// Production (ACR)
// module baseInfra 'br/ContosoACR:bicep/ailz/base:latest' = {

// Development (local)
module baseInfra '../../../bicep/deploy/main.bicep' = {
```

**Note**: Don't commit your actual ACR name to the repository. Each team should configure their own bicepconfig.json locally or via CI/CD.
