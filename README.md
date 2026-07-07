# AKS Demo – Deploy via GitHub Actions

Deze repo bevat:
- `app/` – simpele Express.js app
- `Dockerfile` – multi-stage build, draait als non-root
- `k8s/deployment.yaml` en `k8s/service.yaml` – Kubernetes manifests
- `.github/workflows/deploy-aks.yml` – CI/CD pipeline

## Eenmalige setup in Azure

1. **Resource group, ACR en AKS aanmaken** (indien nog niet aanwezig):
   ```bash
   az group create -n <resource-group> -l westeurope
   az acr create -n <acr-naam> -g <resource-group> --sku Basic
   az aks create -n <cluster-naam> -g <resource-group> \
     --attach-acr <acr-naam> --node-count 2 --generate-ssh-keys
   ```
   `--attach-acr` regelt automatisch dat AKS images uit je ACR mag pullen (geen imagePullSecret nodig).

2. **Federated identity (OIDC) aanmaken**, zodat GitHub Actions kan inloggen zonder secrets op te slaan:
   ```bash
   az ad app create --display-name "gh-actions-aks-demo"
   # noteer de appId (= client-id)

   az ad sp create --id <appId>
   az role assignment create --assignee <appId> --role Contributor \
     --scope /subscriptions/<subscription-id>/resourceGroups/<resource-group>

   az ad app federated-credential create --id <appId> --parameters '{
     "name": "github-main-branch",
     "issuer": "https://token.actions.githubusercontent.com",
     "subject": "repo:<github-org>/<repo-naam>:ref:refs/heads/main",
     "audiences": ["api://AzureADTokenExchange"]
   }'
   ```

3. **GitHub secrets instellen** (Settings → Secrets and variables → Actions):
   - `AZURE_CLIENT_ID` – de appId hierboven
   - `AZURE_TENANT_ID` – je Azure tenant ID
   - `AZURE_SUBSCRIPTION_ID` – je subscription ID

4. **Placeholders invullen** in `.github/workflows/deploy-aks.yml`:
   - `REGISTRY_NAME`, `RESOURCE_GROUP`, `CLUSTER_NAME`

## Werking van de pipeline

Bij elke push naar `main`:
1. Logt in bij Azure via OIDC (geen wachtwoorden/secrets in de image).
2. Bouwt de Docker image direct in ACR met `az acr build` (geen lokale Docker daemon nodig in de runner).
3. Haalt AKS credentials op.
4. Vervangt de image-tag in `deployment.yaml` door de actuele commit SHA (zorgt voor traceerbare, unieke deployments).
5. Past de manifests toe op de cluster.
6. Toont het externe IP van de service.

## Lokaal testen

```bash
cd app && npm install && npm start
# of met Docker:
docker build -t aks-demo-app .
docker run -p 3000:3000 aks-demo-app
```
