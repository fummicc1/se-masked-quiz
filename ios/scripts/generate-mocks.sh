#!/bin/bash

set -e

echo "🔧 Generating mocks with mockolo..."

# Get project root
PROJECT_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
IOS_ROOT="$PROJECT_ROOT/ios"

# Output directory for generated mocks
MOCKS_DIR="$IOS_ROOT/se-masked-quizTests/Generated"
mkdir -p "$MOCKS_DIR"

# Check if mockolo is installed
if ! command -v mockolo &> /dev/null; then
    echo "❌ Error: mockolo is not installed"
    echo "Please install mockolo with: brew install mockolo"
    exit 1
fi

# Run mockolo to generate mocks
echo "🎭 Running mockolo..."
mockolo \
  --sourcedirs "$IOS_ROOT/se-masked-quiz" \
  --destination "$MOCKS_DIR/GeneratedMocks.swift" \
  --testable-imports se_masked_quiz

echo "✅ Mocks generated successfully at $MOCKS_DIR/GeneratedMocks.swift"
