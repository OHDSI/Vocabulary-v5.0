# Azure Container Apps Deployment Guide

Complete guide to deploying the validation proxy to Azure Container Apps with a static outbound IP.

## Option 1: Quick Deploy (Azure Portal)

### Step 1: Build and Push Docker Image

```bash
# Login to Azure
az login

# Create resource group
az group create --name ohdsi-validation-rg --location eastus

# Create Azure Container Registry if needed
az acr create \
  --resource-group ohdsi-validation-rg \
  --name ohdsivalidationacr \
  --sku Basic \
  --admin-enabled true

# Build and push image (here's an example for acr.io)
az acr build \
  --registry ohdsivalidationacr \
  --image validation-proxy:latest \
  --platform linux/amd64 \
  --file Dockerfile .
```


### Step 2: Deploy Container App (to existing )

```bash
# Get ACR credentials
ACR_USERNAME=$(az acr credential show \
  --name ohdsivalidationacr \
  --query username -o tsv)

ACR_PASSWORD=$(az acr credential show \
  --name ohdsivalidationacr \
  --query passwords[0].value -o tsv)

# Create container app
az containerapp create \
  --name validation-proxy \
  --resource-group <some resource group> \
  --environment <some container env> \
  --image <some docker registry>/<some image name> \
  --registry-server <some docker registry> \
  --registry-username $ACR_USERNAME \
  --registry-password $ACR_PASSWORD \
  --target-port 8080 \
  --ingress external \
  --min-replicas 1 \
  --max-replicas 3 \
  --cpu 0.5 \
  --memory 1.0Gi \
  --env-vars \
    DB_HOST=your-db-host.postgres.database.azure.com \
    DB_PORT=5432 \
    DB_NAME=ohdsi_vocab \
    DB_USER=readonly_user \
    DB_PASSWORD=secretref:db-password \
    DB_SSL=true \
    API_KEY=secretref:api-key

# Add secrets
az containerapp secret set \
  --name validation-proxy \
  --resource-group ohdsi-validation-rg \
  --secrets \
    db-password=YOUR_DB_PASSWORD \
    api-key=YOUR_API_KEY
```

### Step 3: Get Application URL

```bash
az containerapp show \
  --name validation-proxy \
  --resource-group ohdsi-validation-rg \
  --query properties.configuration.ingress.fqdn -o tsv
```

Save this URL - you'll need it for Google Apps Script!


## Cost Estimation

Azure Container Apps pricing (East US):

| Component                              | Cost                                  |
|----------------------------------------|---------------------------------------|
| Container App (0.5 CPU, 1GB)           | ~$0.000024/sec = ~$2/day when running |
| Container Registry (Basic - if needed) | $5/month                              |
| Outbound traffic                       | $0.087/GB                             |
| **Total (always-on)**                  | **~$70/month**                        |

