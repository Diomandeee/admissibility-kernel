#!/bin/bash
# Graph Kernel Deployment Script
#
# Deploys the Graph Kernel service to Google Cloud Run
#
# Prerequisites:
#   - gcloud CLI authenticated
#   - Project configured: gcloud config set project YOUR_PROJECT
#   - Secrets created in Secret Manager:
#     - kernel-hmac-secret: HMAC secret for token signing
#     - database-url: PostgreSQL connection string
#
# Usage:
#   ./deploy.sh              # Deploy using Cloud Build
#   ./deploy.sh --local      # Build and push locally

set -euo pipefail

# Configuration
PROJECT_ID="${PROJECT_ID:-$(gcloud config get-value project 2>/dev/null)}"
REGION="${REGION:-us-central1}"
SERVICE_NAME="graph-kernel"
IMAGE_NAME="gcr.io/${PROJECT_ID}/graph-kernel"
SHORT_SHA="${SHORT_SHA:-$(git rev-parse --short HEAD 2>/dev/null || echo 'dev')}"

echo "=============================================="
echo "Graph Kernel Deployment"
echo "=============================================="
echo "Project:  ${PROJECT_ID}"
echo "Region:   ${REGION}"
echo "Service:  ${SERVICE_NAME}"
echo "Image:    ${IMAGE_NAME}:${SHORT_SHA}"
echo "=============================================="

# Check if secrets exist
echo ""
echo "Checking required secrets..."
if ! gcloud secrets describe kernel-hmac-secret --project="${PROJECT_ID}" >/dev/null 2>&1; then
    echo "ERROR: Secret 'kernel-hmac-secret' not found in Secret Manager"
    echo "Create it with: gcloud secrets create kernel-hmac-secret --replication-policy=automatic"
    echo "Add value with: echo -n 'YOUR_SECRET' | gcloud secrets versions add kernel-hmac-secret --data-file=-"
    exit 1
fi

if ! gcloud secrets describe database-url --project="${PROJECT_ID}" >/dev/null 2>&1; then
    echo "ERROR: Secret 'database-url' not found in Secret Manager"
    echo "Create it with: gcloud secrets create database-url --replication-policy=automatic"
    echo "Add value with: echo -n 'postgresql://...' | gcloud secrets versions add database-url --data-file=-"
    exit 1
fi

echo "✓ Required secrets exist"

# Deploy using Cloud Build or local build
if [[ "${1:-}" == "--local" ]]; then
    echo ""
    echo "Building Docker image locally..."

    docker build \
        --no-cache \
        -t "${IMAGE_NAME}:${SHORT_SHA}" \
        -t "${IMAGE_NAME}:latest" \
        -f Dockerfile.service \
        --build-arg BUILD_SHA="${SHORT_SHA}" \
        .

    echo ""
    echo "Pushing to Container Registry..."
    docker push "${IMAGE_NAME}:${SHORT_SHA}"
    docker push "${IMAGE_NAME}:latest"

    echo ""
    echo "Deploying to Cloud Run..."
    gcloud run deploy "${SERVICE_NAME}" \
        --image="${IMAGE_NAME}:${SHORT_SHA}" \
        --platform=managed \
        --region="${REGION}" \
        --no-allow-unauthenticated \
        --port=8001 \
        --memory=1Gi \
        --cpu=1 \
        --min-instances=0 \
        --max-instances=10 \
        --concurrency=50 \
        --timeout=60 \
        --cpu-throttling \
        --startup-cpu-boost \
        --set-secrets="KERNEL_HMAC_SECRET=kernel-hmac-secret:latest,DATABASE_URL=database-url:latest" \
        --set-env-vars="RUST_LOG=info,HOST=0.0.0.0,RUST_BACKTRACE=1" \
        --labels="service=graph-kernel,component=authority-layer" \
        --revision-suffix="${SHORT_SHA}"
else
    echo ""
    echo "Deploying using Cloud Build..."

    gcloud builds submit \
        --config=cloudbuild-service.yaml \
        --substitutions="SHORT_SHA=${SHORT_SHA}" \
        .
fi

echo ""
echo "=============================================="
echo "Deployment complete!"
echo "=============================================="

# Get service URL
SERVICE_URL=$(gcloud run services describe "${SERVICE_NAME}" \
    --platform=managed \
    --region="${REGION}" \
    --format='value(status.url)' 2>/dev/null || echo "")

if [[ -n "${SERVICE_URL}" ]]; then
    echo "Service URL: ${SERVICE_URL}"
    echo ""
    echo "Test health endpoint:"
    echo "  curl -H \"Authorization: Bearer \$(gcloud auth print-identity-token)\" ${SERVICE_URL}/health"
fi

echo ""
echo "To allow public access (NOT recommended for production):"
echo "  gcloud run services add-iam-policy-binding ${SERVICE_NAME} \\"
echo "    --region=${REGION} \\"
echo "    --member='allUsers' \\"
echo "    --role='roles/run.invoker'"
