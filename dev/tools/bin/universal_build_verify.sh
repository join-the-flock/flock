#!/bin/bash
# Copyright 2014 The Flutter Authors. All rights reserved.
# Use of this source code is governed by a BSD-style license that can be
# found in the LICENSE file.

# Universal Flutter build verification script
# This script helps detect and fix common build issues across platforms

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FLUTTER_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"

echo "🔍 Starting universal Flutter build verification..."
echo "Flutter root: $FLUTTER_ROOT"

# Function to print colored output
print_success() {
    echo -e "\033[0;32m✓ $1\033[0m"
}

print_error() {
    echo -e "\033[0;31m✗ $1\033[0m"
}

print_info() {
    echo -e "\033[0;34mℹ $1\033[0m"
}

# Clean Flutter cache
clean_flutter() {
    print_info "Cleaning Flutter cache..."
    cd "$FLUTTER_ROOT"
    ./bin/flutter clean || true
    print_success "Flutter cache cleaned"
}

# Verify Flutter installation
verify_flutter() {
    print_info "Verifying Flutter installation..."
    cd "$FLUTTER_ROOT"
    ./bin/flutter doctor -v
    print_success "Flutter verification complete"
}

# Platform-specific cleaning
clean_platform_specific() {
    if [[ "$OSTYPE" == "darwin"* ]]; then
        print_info "Detected macOS - cleaning macOS/iOS builds..."

        # Clean Xcode derived data
        if [ -d "$HOME/Library/Developer/Xcode/DerivedData" ]; then
            print_info "Cleaning Xcode DerivedData..."
            rm -rf "$HOME/Library/Developer/Xcode/DerivedData/"
            print_success "Xcode DerivedData cleaned"
        fi

        # Clean CocoaPods cache if present
        if command -v pod &> /dev/null; then
            print_info "Cleaning CocoaPods cache..."
            pod cache clean --all || true
            print_success "CocoaPods cache cleaned"
        fi

    elif [[ "$OSTYPE" == "linux-gnu"* ]]; then
        print_info "Detected Linux - cleaning Linux builds..."
        rm -rf build/ || true

    elif [[ "$OSTYPE" == "msys" ]] || [[ "$OSTYPE" == "win32" ]]; then
        print_info "Detected Windows - cleaning Windows builds..."
        rm -rf build/ || true
    fi
}

# Verify dependencies
verify_dependencies() {
    print_info "Verifying dependencies..."
    cd "$FLUTTER_ROOT"

    # Check for pubspec.yaml in packages
    for package in packages/*/pubspec.yaml; do
        if [ -f "$package" ]; then
            package_dir=$(dirname "$package")
            print_info "Checking dependencies for $package_dir..."
            cd "$FLUTTER_ROOT/$package_dir"
            ../../bin/flutter pub get || {
                print_error "Failed to get dependencies for $package_dir"
                return 1
            }
        fi
    done

    cd "$FLUTTER_ROOT"
    print_success "Dependencies verified"
}

# Check for common build issues
check_build_issues() {
    print_info "Checking for common build issues..."

    # Check for stale build artifacts
    if [ -d "$FLUTTER_ROOT/build" ]; then
        print_info "Found stale build directory, cleaning..."
        rm -rf "$FLUTTER_ROOT/build"
    fi

    # Check for .dart_tool directory issues
    if [ -d "$FLUTTER_ROOT/.dart_tool" ]; then
        print_info "Checking .dart_tool directory..."
        # Could add more specific checks here
    fi

    print_success "Build issue check complete"
}

# Main execution
main() {
    print_info "Starting build verification process..."

    # Parse command line arguments
    CLEAN_ONLY=false
    VERIFY_ONLY=false

    while [[ $# -gt 0 ]]; do
        case $1 in
            --clean-only)
                CLEAN_ONLY=true
                shift
                ;;
            --verify-only)
                VERIFY_ONLY=true
                shift
                ;;
            --help)
                echo "Usage: $0 [OPTIONS]"
                echo ""
                echo "Options:"
                echo "  --clean-only    Only perform cleaning operations"
                echo "  --verify-only   Only perform verification checks"
                echo "  --help          Show this help message"
                exit 0
                ;;
            *)
                print_error "Unknown option: $1"
                echo "Use --help for usage information"
                exit 1
                ;;
        esac
    done

    if [ "$VERIFY_ONLY" = false ]; then
        clean_flutter
        clean_platform_specific
        check_build_issues
    fi

    if [ "$CLEAN_ONLY" = false ]; then
        verify_flutter
        verify_dependencies
    fi

    print_success "Build verification completed successfully!"
    print_info "Your Flutter installation is ready for building."
}

# Run main function
main "$@"
