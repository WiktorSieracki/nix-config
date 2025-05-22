#!/bin/bash

# This script recursively pulls the latest changes from the 'main' branch
# for all Git repositories in the current directory.
# It searches for directories containing a .git folder and performs a git pull
# for each repository found.

# Function to print error messages in red
print_error() {
    echo -e "\e[31mERROR: $1\e[0m"
}

# Function to print success messages in green
print_success() {
    echo -e "\e[32m$1\e[0m"
}

# Function to print warnings in yellow
print_warning() {
    echo -e "\e[33mWARNING: $1\e[0m"
}

echo "Starting to pull updates for all Git repositories..."

# Counter for successful and failed pulls
success_count=0
failed_count=0

# Arrays to store repository names
declare -a successful_repos=()
declare -a failed_repos=()

# Iterate through all directories
for dir in */; do
    if [ ! -d "$dir" ]; then
        continue
    fi

    if [ -d "$dir/.git" ]; then
        echo -e "\nProcessing repository: $dir"
        
        # Check if the repository has any remote
        if ! git --git-dir="$dir/.git" --work-tree="$PWD/$dir" remote -v > /dev/null 2>&1; then
            print_error "No remote configured for $dir"
            failed_repos+=("$dir")
            ((failed_count++))
            continue
        fi

        # Check if 'main' branch exists
        if ! git --git-dir="$dir/.git" --work-tree="$PWD/$dir" rev-parse --verify origin/main >/dev/null 2>&1; then
            print_error "Branch 'main' not found in $dir. Please verify the default branch name."
            failed_repos+=("$dir")
            ((failed_count++))
            continue
        fi

        # First try with --ff-only (safest option)
        if git --git-dir="$dir/.git" --work-tree="$PWD/$dir" pull --ff-only origin main; then
            print_success "Successfully pulled latest changes for $dir"
            successful_repos+=("$dir")
            ((success_count++))
        else
            # If ff-only fails, notify the user about divergent branches
            print_warning "Could not fast-forward $dir. You may have local changes."
            print_warning "Options for $dir:"
            print_warning "1. Merge changes:    cd $dir && git pull --no-ff origin main"
            print_warning "2. Rebase changes:   cd $dir && git pull --rebase origin main"
            print_warning "3. Override local:   cd $dir && git fetch origin main && git reset --hard origin/main"
            failed_repos+=("$dir")
            ((failed_count++))
        fi
    fi
done

# Print summary
echo -e "\n=== Summary ==="
if [ $success_count -gt 0 ]; then
    print_success "Successfully pulled changes in $success_count repositories:"
    for repo in "${successful_repos[@]}"; do
        echo -e "\e[32m  ✓\e[0m $repo"
    done
fi

if [ $failed_count -gt 0 ]; then
    echo ""
    print_error "Failed to pull changes in $failed_count repositories:"
    for repo in "${failed_repos[@]}"; do
        echo -e "\e[31m  ✗\e[0m $repo"
    done
fi

# Exit with failure if any repository failed to update
[ $failed_count -gt 0 ] && exit 1 || exit 0