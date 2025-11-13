#!/bin/bash

# Deploy Swift Evolution Quiz website to Cloudflare Pages
# Usage: ./scripts/deploy-website.sh

set -e

# Colors for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${BLUE}🚀 Starting Cloudflare Pages deployment...${NC}"
echo ""

# Check if wrangler is installed
if ! command -v wrangler &> /dev/null; then
    echo -e "${RED}❌ Error: wrangler is not installed${NC}"
    echo "Install it with: npm install -g wrangler"
    exit 1
fi

# Change to project root
cd "$(dirname "$0")/.."

# Project configuration
PROJECT_NAME="se-masked-quiz"
WEBSITE_DIR="website"
CUSTOM_DOMAIN="swift-evolution-quiz.fummicc1.dev"

echo -e "${BLUE}📁 Project: ${PROJECT_NAME}${NC}"
echo -e "${BLUE}📂 Directory: ${WEBSITE_DIR}${NC}"
echo -e "${BLUE}🌐 Custom Domain: ${CUSTOM_DOMAIN}${NC}"
echo ""

# Deploy to Cloudflare Pages
echo -e "${BLUE}📤 Deploying to Cloudflare Pages...${NC}"
npx wrangler pages deploy "${WEBSITE_DIR}" \
  --project-name="${PROJECT_NAME}"

echo ""
echo -e "${GREEN}✅ Deployment completed successfully!${NC}"
echo ""
echo -e "${BLUE}🌐 Website URLs:${NC}"
echo -e "  Main: ${GREEN}https://${PROJECT_NAME}.pages.dev/${NC}"
echo -e "  Custom: ${GREEN}https://${CUSTOM_DOMAIN}/${NC} ${YELLOW}(after DNS setup)${NC}"
echo ""
echo -e "${BLUE}📄 Pages:${NC}"
echo -e "  Landing Page: ${GREEN}https://${CUSTOM_DOMAIN}/${NC}"
echo -e "  Privacy (日本語): ${GREEN}https://${CUSTOM_DOMAIN}/privacy/privacy-policy.html${NC}"
echo -e "  Privacy (English): ${GREEN}https://${CUSTOM_DOMAIN}/privacy/privacy-policy-en.html${NC}"
echo ""
echo -e "${YELLOW}⚙️  Next Step: Set up custom domain in Cloudflare Pages dashboard${NC}"
