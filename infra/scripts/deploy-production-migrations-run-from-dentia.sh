#!/bin/bash

# Script to deploy migrations to production database
# This script properly handles special characters in passwords

set -e

echo "🚀 Deploying migrations to production database..."
echo ""

# Check if we're in the right directory
if [ ! -f "package.json" ]; then
  echo "❌ Error: Please run this script from the project root"
  exit 1
fi

# Database connection details
DB_USER="dentia_admin"
DB_PASSWORD="S7#tY4^zN9_Rq2+xS8!nV9d"
DB_HOST="localhost"
DB_PORT="15432"
DB_NAME="dentia"

# URL encode the password
# This handles special characters properly
URL_ENCODED_PASSWORD=$(python3 -c "import urllib.parse; print(urllib.parse.quote('$DB_PASSWORD', safe=''))")

# Construct the database URL
DATABASE_URL="postgresql://${DB_USER}:${URL_ENCODED_PASSWORD}@${DB_HOST}:${DB_PORT}/${DB_NAME}?schema=public"

echo "📦 Running Prisma migrations..."
echo "   Host: $DB_HOST:$DB_PORT"
echo "   Database: $DB_NAME"
echo "   User: $DB_USER"
echo ""

# Run migrations
PRISMA_IGNORE_ENV_FILE=1 \
DATABASE_URL="$DATABASE_URL" \
pnpm --filter @kit/prisma migrate:deploy

echo ""
echo "✅ Migrations deployed successfully!"
echo ""
echo "🌱 Do you want to seed the database with roles and permissions? (y/N)"
read -r SEED_DB

if [[ "$SEED_DB" =~ ^[Yy]$ ]]; then
  echo ""
  echo "🌱 Seeding database..."
  PRISMA_IGNORE_ENV_FILE=1 \
  DATABASE_URL="$DATABASE_URL" \
  pnpm --filter @kit/prisma db:seed
  
  echo ""
  echo "✅ Database seeded successfully!"
fi

echo ""
echo "🎉 Production database is ready!"

