#!/bin/bash
# setup.sh — first-time project setup

set -e

echo "🔧 MLEbotics monorepo setup"

# Check required tools
command -v node >/dev/null || { echo "❌ Node.js not found. Install v20+"; exit 1; }
command -v pnpm >/dev/null || { echo "❌ pnpm not found. Run: npm install -g pnpm"; exit 1; }

# Install dependencies
echo "📦 Installing dependencies..."
pnpm install

# Copy env files if they don't exist
[ ! -f .env ] && cp .env.example .env && echo "✅ Created .env from .env.example"

echo ""
echo "✅ Setup complete!"
echo ""
echo "Next steps:"
echo "  pnpm dev              — start all apps"
echo "  pnpm dev:web          — start dashboard only (localhost:3001)"
echo "  pnpm dev:marketing    — start marketing site only (localhost:4321)"
