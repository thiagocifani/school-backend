#!/bin/bash

# Set CORS environment variables for Heroku deployment
echo "🔧 Setting CORS environment variables for Heroku..."

# API App Name (from the error message)
API_APP_NAME="raaizes-api"
FRONTEND_URL="https://raizes-frontend-994c596b2d99.herokuapp.com"

echo "Setting FRONTEND_URL for API app: $API_APP_NAME"
heroku config:set FRONTEND_URL="$FRONTEND_URL" --app "$API_APP_NAME"

echo "✅ Environment variables set successfully!"
echo ""
echo "Now deploying updated CORS configuration..."
echo ""

# Redeploy API with new CORS config
cd school-api || { echo "Error: school-api directory not found"; exit 1; }

# Commit and deploy the CORS changes
git add .
git commit -m "Fix CORS configuration for production deployment"

echo "Pushing to Heroku..."
git push heroku main

echo ""
echo "🚀 Deployment complete!"
echo ""
echo "✅ CORS should now be fixed. Try accessing your frontend again:"
echo "   Frontend: https://raizes-frontend-994c596b2d99.herokuapp.com"
echo "   API: https://raaizes-api.herokuapp.com"

