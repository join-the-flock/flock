#!/bin/bash
# Copyright 2014 The Flutter Authors. All rights reserved.
# Use of this source code is governed by a BSD-style license that can be
# found in the LICENSE file.

# Safe release builder script with race condition prevention
# This script addresses concurrent access issues when multiple release
# builders try to update the same release JSON files.

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOCK_FILE="/tmp/flutter_release_${PLATFORM:-unknown}.lock"
LOCK_TIMEOUT=300  # 5 minutes
RELEASE_JSON_FILE="releases_${PLATFORM}.json"

# Function to print colored output
print_info() {
    echo -e "\033[0;34m[INFO]\033[0m $1"
}

print_success() {
    echo -e "\033[0;32m[SUCCESS]\033[0m $1"
}

print_error() {
    echo -e "\033[0;31m[ERROR]\033[0m $1" >&2
}

print_warning() {
    echo -e "\033[0;33m[WARNING]\033[0m $1"
}

# Function to acquire lock with timeout
acquire_lock() {
    local elapsed=0

    print_info "Attempting to acquire lock: $LOCK_FILE"

    while ! mkdir "$LOCK_FILE" 2>/dev/null; do
        if [ $elapsed -ge $LOCK_TIMEOUT ]; then
            print_error "Failed to acquire lock after ${LOCK_TIMEOUT} seconds"
            print_error "Lock file: $LOCK_FILE"

            # Check if lock is stale (older than timeout)
            if [ -d "$LOCK_FILE" ]; then
                local lock_age=$(($(date +%s) - $(stat -f%m "$LOCK_FILE" 2>/dev/null || stat -c%Y "$LOCK_FILE")))
                if [ $lock_age -gt $LOCK_TIMEOUT ]; then
                    print_warning "Lock appears stale (${lock_age}s old), forcefully removing..."
                    rm -rf "$LOCK_FILE"
                    # Try one more time
                    if mkdir "$LOCK_FILE" 2>/dev/null; then
                        print_success "Acquired lock after removing stale lock"
                        return 0
                    fi
                fi
            fi

            exit 1
        fi

        print_info "Lock held by another process, waiting... (${elapsed}s/${LOCK_TIMEOUT}s)"
        sleep 1
        elapsed=$((elapsed + 1))
    done

    # Store PID in lock directory for debugging
    echo $$ > "$LOCK_FILE/pid"
    echo "$(date -u +%Y-%m-%dT%H:%M:%SZ)" > "$LOCK_FILE/timestamp"
    echo "$PLATFORM" > "$LOCK_FILE/platform"

    print_success "Lock acquired successfully"

    # Set trap to release lock on exit
    trap 'release_lock' INT TERM EXIT

    return 0
}

# Function to release lock
release_lock() {
    if [ -d "$LOCK_FILE" ]; then
        print_info "Releasing lock: $LOCK_FILE"
        rm -rf "$LOCK_FILE"
        print_success "Lock released"
    fi

    # Remove trap
    trap - INT TERM EXIT
}

# Function to verify lock is still held
verify_lock() {
    if [ ! -d "$LOCK_FILE" ]; then
        print_error "Lock lost during operation!"
        exit 1
    fi

    # Verify our PID is in the lock
    if [ -f "$LOCK_FILE/pid" ]; then
        local lock_pid=$(cat "$LOCK_FILE/pid")
        if [ "$lock_pid" != "$$" ]; then
            print_error "Lock file PID mismatch! Expected $$, found $lock_pid"
            exit 1
        fi
    fi
}

# Function to safely update JSON file
update_json_file() {
    local json_file="$1"
    local temp_file="${json_file}.tmp.$$"
    local backup_file="${json_file}.backup.$$"

    print_info "Updating JSON file: $json_file"

    # Verify lock is still held
    verify_lock

    # Create backup of existing file
    if [ -f "$json_file" ]; then
        cp "$json_file" "$backup_file"
        print_info "Created backup: $backup_file"
    fi

    # Download current version from cloud storage (if applicable)
    if [ -n "$CLOUD_STORAGE_PATH" ]; then
        print_info "Downloading current version from cloud storage..."
        if gsutil cp "$CLOUD_STORAGE_PATH/$json_file" "$temp_file" 2>/dev/null; then
            print_success "Downloaded current version"
        else
            print_warning "Could not download from cloud storage, using local version"
            if [ -f "$json_file" ]; then
                cp "$json_file" "$temp_file"
            else
                echo '{"releases": []}' > "$temp_file"
            fi
        fi
    else
        if [ -f "$json_file" ]; then
            cp "$json_file" "$temp_file"
        else
            echo '{"releases": []}' > "$temp_file"
        fi
    fi

    # Verify lock again before modifying
    verify_lock

    # Merge new release data (this would be implemented based on specific needs)
    # For now, we just demonstrate the safe update pattern
    print_info "Merging release data..."

    # TODO: Actual merge logic goes here
    # This would use jq or similar to safely merge JSON

    # Verify lock one more time before writing
    verify_lock

    # Atomically replace the file
    mv "$temp_file" "$json_file"
    print_success "JSON file updated successfully"

    # Upload to cloud storage (if applicable)
    if [ -n "$CLOUD_STORAGE_PATH" ]; then
        print_info "Uploading updated version to cloud storage..."
        if gsutil cp "$json_file" "$CLOUD_STORAGE_PATH/$json_file"; then
            print_success "Uploaded to cloud storage"
        else
            print_error "Failed to upload to cloud storage"
            # Restore backup
            if [ -f "$backup_file" ]; then
                mv "$backup_file" "$json_file"
                print_warning "Restored backup due to upload failure"
            fi
            return 1
        fi
    fi

    # Clean up backup
    if [ -f "$backup_file" ]; then
        rm "$backup_file"
        print_info "Cleaned up backup file"
    fi

    return 0
}

# Function to handle errors
handle_error() {
    local exit_code=$1
    print_error "Release builder failed with exit code: $exit_code"

    # Release lock if held
    release_lock

    exit $exit_code
}

# Main release process
main() {
    print_info "Starting safe release process for platform: ${PLATFORM:-unknown}"

    # Validate environment
    if [ -z "$PLATFORM" ]; then
        print_error "PLATFORM environment variable not set"
        exit 1
    fi

    # Set error handler
    set -E
    trap 'handle_error $?' ERR

    # Acquire exclusive lock
    acquire_lock

    # Verify lock is held
    verify_lock

    # Perform release operations
    print_info "Executing release operations..."

    # Update release JSON with race condition protection
    if ! update_json_file "$RELEASE_JSON_FILE"; then
        print_error "Failed to update release JSON"
        handle_error 1
    fi

    # Additional release steps would go here
    print_info "Performing additional release steps..."

    # Simulate some work
    sleep 1

    # Verify lock is still held
    verify_lock

    print_success "Release process completed successfully"

    # Lock will be released automatically via trap
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --platform)
            PLATFORM="$2"
            shift 2
            ;;
        --cloud-storage)
            CLOUD_STORAGE_PATH="$2"
            shift 2
            ;;
        --timeout)
            LOCK_TIMEOUT="$2"
            shift 2
            ;;
        --help)
            echo "Usage: $0 [OPTIONS]"
            echo ""
            echo "Options:"
            echo "  --platform PLATFORM      Platform name (required)"
            echo "  --cloud-storage PATH     Cloud storage path for release files"
            echo "  --timeout SECONDS        Lock timeout in seconds (default: 300)"
            echo "  --help                   Show this help message"
            exit 0
            ;;
        *)
            print_error "Unknown option: $1"
            echo "Use --help for usage information"
            exit 1
            ;;
    esac
done

# Run main function
main
