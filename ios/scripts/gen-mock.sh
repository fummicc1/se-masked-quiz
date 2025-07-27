#!/bin/bash

if ! command -v mockolo >/dev/null; then
    echo "mockolo is not installed. Please install it to generate mocks."
    exit 1
fi

cd "$(dirname "$0")/.."

mockolo -s se-masked-quiz --destination se-masked-quizTests/GeneratedMocks.swift --testable-imports se_masked_quiz