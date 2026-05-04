# n8n Connection Setup Guide

## 1. GCP Service Account (Least Privilege)
Create a Service Account named `n8n-orchestrator` in the Google Cloud Console and assign these roles:
- `roles/cloudfunctions.developer`: To monitor and trigger functions.
- `roles/datastore.user`: To query/write Firestore test data. (Cloud Datastore User)
- `roles/logging.viewer`: To tail deployment logs. (Logs Viewer)
- `roles/firebase.admin`: To verify Hosting status. 

## 2. GitHub PAT (Fine-Grained)
Create a token in GitHub Settings (Developer Settings) with access to your repository and the following scopes:
- `contents:write`: To push code updates and update the .l2laaf/state.json.
- `workflows:write`: To trigger or monitor GitHub Actions.

## 3. Google Chat Webhook
1. Open Google Chat.
2. Go to the space where you want notifications.
3. Click the space name > **Apps & integrations** > **Webhooks**
4. Add a webhook named "L2LAAF Orchestrator" and copy the URL.