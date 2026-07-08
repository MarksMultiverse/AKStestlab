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

## Optie: deployen met Helm

Naast de losse manifests in `k8s/` bevat de repo ook een volwaardige Helm chart in
`helm/aks-demo-app/`, met bijbehorende workflow `.github/workflows/deploy-aks-helm.yml`.

Voordelen ten opzichte van kale manifests:
- **Eén release beheren** – `helm upgrade --install` maakt de resources aan als ze nog niet bestaan, of werkt ze bij.
- **`--atomic`** – bij een mislukte deployment rolt Helm automatisch terug naar de vorige werkende versie.
- **Configuratie per omgeving** – via aparte `values-staging.yaml` / `values-prod.yaml` bestanden, zonder de templates te wijzigen.
- **Versiegeschiedenis** – `helm history aks-demo-app` toont alle eerdere releases, `helm rollback` voor handmatige rollback.

Gebruik **óf** `deploy-aks.yml` (kubectl + manifests) **óf** `deploy-aks-helm.yml` (Helm) – niet beide tegelijk, anders krijg je conflicterende resources omdat Helm zijn eigen labels/annotaties op resources zet.

### Lokaal de chart testen
```bash
# Templates renderen zonder te deployen (handig om te controleren)
helm template aks-demo-app ./helm/aks-demo-app \
  --set image.registry=<acr-naam>.azurecr.io \
  --set image.tag=latest

# Chart valideren
helm lint ./helm/aks-demo-app

# Handmatig deployen
helm upgrade aks-demo-app ./helm/aks-demo-app \
  --install --namespace default --create-namespace \
  --set image.registry=<acr-naam>.azurecr.io \
  --set image.tag=latest
```

### Environment-specifieke waarden
Maak bijvoorbeeld `helm/aks-demo-app/values-prod.yaml` aan met alleen de afwijkende waarden:
```yaml
replicaCount: 4
autoscaling:
  enabled: true
```
En deploy met:
```bash
helm upgrade aks-demo-app ./helm/aks-demo-app -f helm/aks-demo-app/values-prod.yaml --install
```

## Lokaal testen

```bash
cd app && npm install && npm start
# of met Docker:
docker build -t aks-demo-app .
docker run -p 3000:3000 aks-demo-app
```
