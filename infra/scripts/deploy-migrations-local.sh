#!/bin/bash

set -e

echo "============================================"
echo "🗄️  Local Database Migration Deployment"
echo "============================================"
echo ""

# Check if we're in the right directory
if [ ! -f "package.json" ]; then
  echo "❌ Error: Must run from project root"
  exit 1
fi

# Check if Prisma schema exists
if [ ! -f "packages/prisma/schema.prisma" ]; then
  echo "❌ Error: Prisma schema not found at packages/prisma/schema.prisma"
  exit 1
fi

# Check for pending migrations
if [ ! -d "packages/prisma/migrations" ] || [ -z "$(ls -A packages/prisma/migrations)" ]; then
  echo "⚠️  No migrations found in packages/prisma/migrations"
  echo "Nothing to deploy."
  exit 0
fi

echo "📋 Found migrations:"
ls -1 packages/prisma/migrations | grep -v "migration_lock.toml" || true
echo ""

# Check if DATABASE_URL is set
if [ -z "$DATABASE_URL" ]; then
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo "⚠️  DATABASE_URL not set"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo ""
  echo "For local port forwarding, set DATABASE_URL like this:"
  echo ""
  echo "export DATABASE_URL='postgresql://dentia_admin:S7%23tY4%5EzN9_Rq2%2BxS8%21nV9d@localhost:15432/dentia?schema=public'"
  echo ""
  echo "Note: The password is URL-encoded:"
  echo "  # -> %23"
  echo "  ^ -> %5E"
  echo "  + -> %2B"
  echo "  ! -> %21"
  echo ""
  echo "Or use the dentia-infra script:"
  echo "  cd /Users/shaunk/Projects/Dentia/dentia-infra/infra/scripts"
  echo "  ./deploy-production-migrations-run-from-dentia.sh"
  echo ""
  exit 1
fi

echo "✅ Using DATABASE_URL from environment"
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Deploying Migrations"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# Navigate to Prisma directory
cd packages/prisma

# Run migration deployment
echo "Running: npx prisma migrate deploy"
echo ""

if npx prisma migrate deploy; then
  echo ""
  echo "✅ Migrations deployed successfully!"
  echo ""
  echo "📊 Current migration status:"
  npx prisma migrate status || true
else
  echo ""
  echo "❌ Migration deployment failed!"
  exit 1
fi

cd ../..

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "✅ Migration Deployment Complete!"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

