#!/bin/bash
#
# setup-github.sh - Automated GitHub repository setup for ASCII-OS
#
# This script helps you properly upload ASCII-OS to GitHub with all files,
# including the .github workflow directory.

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

print_header() {
    echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
    echo -e "${BLUE}  ASCII-OS GitHub Setup Script${NC}"
    echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
    echo ""
}

print_success() {
    echo -e "${GREEN}✓${NC} $1"
}

print_error() {
    echo -e "${RED}✗${NC} $1"
}

print_info() {
    echo -e "${YELLOW}ℹ${NC} $1"
}

print_step() {
    echo -e "${BLUE}▶${NC} $1"
}

# Check if we're in the right directory
check_directory() {
    if [ ! -f "Makefile" ] || [ ! -f "src/main.c" ]; then
        print_error "Not in ASCII-OS directory!"
        echo ""
        echo "Please run this script from the uefi-ascii-os/ directory:"
        echo "  cd uefi-ascii-os"
        echo "  ./setup-github.sh"
        exit 1
    fi
    print_success "Found ASCII-OS files"
}

# Check if git is installed
check_git() {
    if ! command -v git &> /dev/null; then
        print_error "Git is not installed!"
        echo ""
        echo "Install git first:"
        echo "  Ubuntu/Debian: sudo apt install git"
        echo "  macOS: brew install git"
        exit 1
    fi
    print_success "Git is installed"
}

# Verify all critical files exist
verify_files() {
    print_step "Verifying critical files..."
    
    local missing=0
    
    # Critical files
    files=(
        "Makefile"
        "src/main.c"
        ".github/workflows/build.yml"
        "README.md"
        "LICENSE"
    )
    
    for file in "${files[@]}"; do
        if [ ! -f "$file" ]; then
            print_error "Missing: $file"
            missing=1
        else
            print_success "Found: $file"
        fi
    done
    
    if [ $missing -eq 1 ]; then
        print_error "Some files are missing. Please extract the complete tarball."
        exit 1
    fi
    
    echo ""
}

# Initialize git repository
init_git() {
    print_step "Initializing Git repository..."
    
    if [ -d ".git" ]; then
        print_info "Git repository already initialized"
    else
        git init
        print_success "Git repository initialized"
    fi
    
    # Check current branch
    current_branch=$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "none")
    
    if [ "$current_branch" != "main" ]; then
        print_info "Renaming branch to 'main'"
        git branch -M main
    fi
    
    print_success "On branch: main"
    echo ""
}

# Configure git if needed
configure_git() {
    print_step "Checking Git configuration..."
    
    user_name=$(git config user.name 2>/dev/null || echo "")
    user_email=$(git config user.email 2>/dev/null || echo "")
    
    if [ -z "$user_name" ]; then
        echo ""
        read -p "Enter your name for Git commits: " name
        git config user.name "$name"
    fi
    
    if [ -z "$user_email" ]; then
        echo ""
        read -p "Enter your email for Git commits: " email
        git config user.email "$email"
    fi
    
    print_success "Git configured"
    echo ""
}

# Add all files to git
add_files() {
    print_step "Adding files to Git..."
    
    # Add all files
    git add .
    
    # Force add .github (sometimes ignored)
    git add -f .github/ 2>/dev/null || true
    git add -f .github/workflows/build.yml 2>/dev/null || true
    
    # Check what was added
    staged=$(git diff --cached --name-only | wc -l)
    
    if [ $staged -eq 0 ]; then
        print_error "No files were staged!"
        echo "This might mean all files are already committed."
        echo "Continuing anyway..."
    else
        print_success "Staged $staged files"
    fi
    
    echo ""
}

# Create commit
create_commit() {
    print_step "Creating commit..."
    
    # Check if there are changes to commit
    if git diff-index --quiet HEAD -- 2>/dev/null; then
        print_info "No changes to commit (already up to date)"
        return
    fi
    
    commit_msg="Add ASCII-OS v2.0 with draggable windows and desktop features

Features:
- Movable/draggable windows
- GNOME-inspired modern interface
- Desktop wallpaper pattern
- Full mouse support
- GitHub Actions CI/CD
- Rufus compatible ISO"
    
    git commit -m "$commit_msg" || {
        print_info "Creating initial commit..."
        git commit -m "$commit_msg"
    }
    
    print_success "Commit created"
    echo ""
}

# Setup GitHub remote
setup_remote() {
    print_step "Setting up GitHub remote..."
    echo ""
    
    # Check if remote already exists
    existing_remote=$(git remote get-url origin 2>/dev/null || echo "")
    
    if [ -n "$existing_remote" ]; then
        echo "Current remote: $existing_remote"
        read -p "Keep this remote? (y/n): " keep_remote
        
        if [ "$keep_remote" != "y" ]; then
            git remote remove origin
            existing_remote=""
        fi
    fi
    
    if [ -z "$existing_remote" ]; then
        echo ""
        echo "Enter your GitHub repository URL."
        echo "Example: https://github.com/yourusername/ascii-os.git"
        echo "      or git@github.com:yourusername/ascii-os.git"
        echo ""
        read -p "GitHub repository URL: " repo_url
        
        if [ -z "$repo_url" ]; then
            print_error "No repository URL provided"
            exit 1
        fi
        
        git remote add origin "$repo_url"
        print_success "Remote 'origin' added: $repo_url"
    else
        print_success "Using existing remote: $existing_remote"
    fi
    
    echo ""
}

# Push to GitHub
push_to_github() {
    print_step "Pushing to GitHub..."
    echo ""
    
    echo "This will push to the 'main' branch."
    echo "If this is your first push, use '--force'."
    echo ""
    read -p "Force push? This will overwrite remote (y/n): " force_push
    
    if [ "$force_push" = "y" ]; then
        git push -u origin main --force
    else
        git push -u origin main
    fi
    
    if [ $? -eq 0 ]; then
        print_success "Successfully pushed to GitHub!"
    else
        print_error "Push failed. Check your credentials and repository URL."
        exit 1
    fi
    
    echo ""
}

# Final instructions
show_next_steps() {
    print_header
    print_success "Setup complete!"
    echo ""
    echo "Next steps:"
    echo ""
    echo "1. Enable GitHub Actions:"
    echo "   - Go to your repository on GitHub"
    echo "   - Click the 'Actions' tab"
    echo "   - Click 'I understand my workflows, go ahead and enable them'"
    echo ""
    echo "2. Check the build:"
    echo "   - Go to Actions tab"
    echo "   - You should see 'Build ASCII-OS' workflow running"
    echo "   - Wait for it to complete (green checkmark)"
    echo ""
    echo "3. Download artifacts:"
    echo "   - Click on the successful workflow run"
    echo "   - Scroll to 'Artifacts' section"
    echo "   - Download 'ascii-os-build'"
    echo ""
    echo "4. Test with Rufus:"
    echo "   - Extract ascii-os.iso from the artifact"
    echo "   - Flash to USB with Rufus (DD Image mode)"
    echo "   - Boot and enjoy!"
    echo ""
    
    # Try to get the repo URL
    repo_url=$(git remote get-url origin 2>/dev/null || echo "")
    if [ -n "$repo_url" ]; then
        # Convert to https URL for display
        if [[ $repo_url == git@github.com:* ]]; then
            repo_url=${repo_url/git@github.com:/https://github.com/}
            repo_url=${repo_url/.git/}
        fi
        
        echo -e "${BLUE}Your repository:${NC} $repo_url"
        echo -e "${BLUE}Actions page:${NC} $repo_url/actions"
    fi
    
    echo ""
    echo "If you encounter any issues, see GITHUB_SETUP.md for troubleshooting."
    echo ""
}

# Main execution
main() {
    print_header
    
    check_git
    check_directory
    verify_files
    init_git
    configure_git
    add_files
    create_commit
    setup_remote
    push_to_github
    show_next_steps
}

# Run main
main
