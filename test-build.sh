#!/bin/bash
# Script to simulate GitHub Actions workflow locally

set -e  # Exit on error

echo "=== Simulating GitHub Actions workflow ==="
echo ""

# Step 1: Detect package manager (similar to workflow)
echo "Step 1: Detecting package manager..."
if [ -f "yarn.lock" ] && command -v yarn &> /dev/null; then
    MANAGER="yarn"
    COMMAND="install"
    RUNNER="yarn"
    echo "Detected: yarn"
elif [ -f "package.json" ]; then
    MANAGER="npm"
    COMMAND="ci"
    RUNNER="npx --no-install"
    echo "Detected: npm (yarn.lock exists but yarn not installed, using npm)"
else
    echo "Error: Unable to determine package manager"
    exit 1
fi

# Step 2: Install dependencies
echo ""
echo "Step 2: Installing dependencies..."
$MANAGER $COMMAND

# Step 3: Verify next.config.js
echo ""
echo "Step 3: Verifying next.config.js..."
if [ -f "next.config.js" ]; then
    echo "Current next.config.js:"
    cat next.config.js
    echo ""
    
    # Check if output: 'export' is present
    if grep -q "output.*export" next.config.js; then
        echo "✓ output: 'export' is configured"
    else
        echo "⚠ Warning: output: 'export' not found in config"
    fi
else
    echo "Error: next.config.js not found"
    exit 1
fi

# Step 4: Build with Next.js
echo ""
echo "Step 4: Building with Next.js..."
$RUNNER next build

# Step 4b: Export static site (required for Next.js 12)
echo ""
echo "Step 4b: Exporting static site..."
$RUNNER next export

# Step 5: Check build output
echo ""
echo "Step 5: Checking build output..."
echo "Current directory contents:"
ls -la

echo ""
echo "Checking .next directory:"
if [ -d ".next" ]; then
    ls -la .next | head -10
else
    echo ".next directory not found"
fi

echo ""
echo "Checking for 'out' directory:"
if [ -d "./out" ]; then
    echo "✓ Found 'out' directory!"
    echo "Contents:"
    ls -la ./out | head -20
    echo ""
    echo "Total files in 'out':"
    find ./out -type f | wc -l
else
    echo "✗ 'out' directory NOT found!"
    echo ""
    echo "This means the static export did not work."
    echo "Please check:"
    echo "  1. Is 'output: export' configured in next.config.js?"
    echo "  2. Are there any build errors above?"
    exit 1
fi

echo ""
echo "=== Build simulation completed successfully! ==="

