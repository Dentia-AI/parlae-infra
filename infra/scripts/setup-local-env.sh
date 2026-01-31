#!/bin/bash
# Setup local development environment with platform credentials
# This script is for LOCAL DEVELOPMENT ONLY
# For production, use put-ssm-secrets.sh

set -e

echo "🔧 Dentia Local Development Setup"
echo "=================================="
echo ""

# Check if we're in the dentia project directory
if [ ! -f "../dentia/docker-compose.yml" ]; then
    echo "❌ Error: This script should be run from dentia-infra/infra/scripts/"
    echo "   and expects dentia to be in ../dentia/"
    exit 1
fi

DENTIA_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)/dentia"
ENV_FILE="$DENTIA_ROOT/.env"

echo "📁 Target: $ENV_FILE"
echo ""

# Check if .env exists
if [ -f "$ENV_FILE" ]; then
    echo "✅ Found existing .env file"
    read -p "Do you want to update it with platform credentials? (y/N): " -n 1 -r
    echo ""
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "❌ Cancelled"
        exit 0
    fi
else
    echo "📝 Creating new .env file"
    touch "$ENV_FILE"
fi

# Function to add or update env variable
add_or_update_env() {
    local key=$1
    local value=$2
    local comment=$3
    
    if grep -q "^${key}=" "$ENV_FILE"; then
        # Update existing
        sed -i.bak "s|^${key}=.*|${key}=${value}|" "$ENV_FILE"
        rm "${ENV_FILE}.bak" 2>/dev/null || true
        echo "✅ Updated ${key}"
    else
        # Add new
        if [ -n "$comment" ]; then
            echo "" >> "$ENV_FILE"
            echo "# ${comment}" >> "$ENV_FILE"
        fi
        echo "${key}=${value}" >> "$ENV_FILE"
        echo "📝 Added ${key}"
    fi
}

# Stripe (TEST keys for local development)
STRIPE_PUBLISHABLE_KEY_TEST="pk_test_51SNPE0F4uIWy4U8Oeym4GAm2pF660TYrVr6HuJznY8oa6kJd4rmVBuY2ZRKjVX2Ms8GYbF8tOFTzl5VSA2jGynA600oxAI4nXv"
STRIPE_SECRET_KEY_TEST="sk_test_YOUR_STRIPE_TEST_SECRET_KEY"

add_or_update_env "NEXT_PUBLIC_STRIPE_PUBLISHABLE_KEY" "$STRIPE_PUBLISHABLE_KEY_TEST" "Stripe Configuration (TEST KEYS)"
add_or_update_env "STRIPE_PUBLISHABLE_KEY" "$STRIPE_PUBLISHABLE_KEY_TEST"
add_or_update_env "STRIPE_SECRET_KEY" "$STRIPE_SECRET_KEY_TEST"
add_or_update_env "STRIPE_PUBLISHABLE_KEY_TEST" "$STRIPE_PUBLISHABLE_KEY_TEST"
add_or_update_env "STRIPE_SECRET_KEY_TEST" "$STRIPE_SECRET_KEY_TEST"

# GoHighLevel
GHL_API_KEY="pit-8a1eae7c-9011-479c-ab50-274754b3ae0b"
GHL_LOCATION_ID="J37kckNEAfKpTFpUSEah"
GHL_WIDGET_ID="691e8abd467a1f1c86f74fbf"
GHL_CALENDAR_ID="VOACGbH1cvMBqNCyQjzw"

add_or_update_env "GHL_API_KEY" "$GHL_API_KEY" "GoHighLevel Configuration"
add_or_update_env "GHL_LOCATION_ID" "$GHL_LOCATION_ID"
add_or_update_env "NEXT_PUBLIC_GHL_WIDGET_ID" "$GHL_WIDGET_ID"
add_or_update_env "NEXT_PUBLIC_GHL_LOCATION_ID" "$GHL_LOCATION_ID"
add_or_update_env "NEXT_PUBLIC_GHL_CALENDAR_ID" "$GHL_CALENDAR_ID"

echo ""
echo "✅ Setup complete!"
echo ""
echo "📁 Credentials added to: $ENV_FILE"
echo ""
echo "Next steps:"
echo "1. Start the services:"
echo "   cd $DENTIA_ROOT"
echo "   docker-compose up -d"
echo ""
echo "2. Test the integrations:"
echo "   docker-compose logs -f backend"
echo ""
echo "⚠️  SECURITY NOTE:"
echo "   These credentials are for LOCAL DEVELOPMENT only"
echo "   Production credentials are managed via AWS SSM Parameter Store"
echo "   Run: ./put-ssm-secrets.sh (for production deployment)"
echo ""

