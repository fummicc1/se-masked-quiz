#!/bin/bash

set -euo pipefail

echo "🔧 Generating mocks with mockolo..."

# Get project root
PROJECT_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
IOS_ROOT="$PROJECT_ROOT/ios"

# Output directory for generated mocks
MOCKS_DIR="$IOS_ROOT/se-masked-quizTests/Generated"
mkdir -p "$MOCKS_DIR"

# Check if mint is installed
if ! command -v mint &> /dev/null; then
    echo "❌ Error: mint is not installed"
    echo "Please install mint with: brew install mint"
    exit 1
fi

# Ensure pinned mockolo is bootstrapped from Mintfile
echo "📦 Bootstrapping mockolo from Mintfile..."
(cd "$IOS_ROOT" && mint bootstrap --mintfile Mintfile)

# Run mockolo (pinned by Mintfile) to generate mocks
echo "🎭 Running mockolo..."
(cd "$IOS_ROOT" && mint run mockolo \
  --sourcedirs "$IOS_ROOT/se-masked-quiz" \
  --destination "$MOCKS_DIR/GeneratedMocks.swift" \
  --testable-imports se_masked_quiz)

echo "✅ Mocks generated successfully at $MOCKS_DIR/GeneratedMocks.swift"
