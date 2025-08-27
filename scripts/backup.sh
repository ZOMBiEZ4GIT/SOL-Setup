#!/usr/bin/env bash
set -euo pipefail

# Enhanced backup script with compression, encryption, and cloud storage
# Supports Proton Drive and GitHub backup with retention policies

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
BACKUP_DIR="$PROJECT_ROOT/backups"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
BACKUP_NAME="homelab_backup_${TIMESTAMP}"

# Configuration
RETENTION_DAYS=30
COMPRESS=true
ENCRYPT=true
ENCRYPTION_PASSWORD_FILE="$PROJECT_ROOT/.backup_password"
PROTON_DRIVE_BACKUP=true
GITHUB_BACKUP=true
GITHUB_REPO="your-username/your-backup-repo"  # Update this

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

log() {
    echo -e "${BLUE}[$(date +'%Y-%m-%d %H:%M:%S')]${NC} $1"
}

error() {
    echo -e "${RED}[ERROR]${NC} $1" >&2
}

warn() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

# Check dependencies
check_dependencies() {
    local deps=("tar" "gzip" "openssl" "rclone" "git")
    local missing=()
    
    for dep in "${deps[@]}"; do
        if ! command -v "$dep" &> /dev/null; then
            missing+=("$dep")
        fi
    done
    
    if [ ${#missing[@]} -ne 0 ]; then
        error "Missing dependencies: ${missing[*]}"
        error "Please install: sudo apt install ${missing[*]}"
        exit 1
    fi
}

# Create backup directories
setup_directories() {
    log "Setting up backup directories..."
    mkdir -p "$BACKUP_DIR"
    mkdir -p "$BACKUP_DIR/temp"
    mkdir -p "$BACKUP_DIR/encrypted"
    mkdir -p "$BACKUP_DIR/cloud"
}

# Generate encryption password if not exists
setup_encryption() {
    if [ ! -f "$ENCRYPTION_PASSWORD_FILE" ]; then
        log "Generating new encryption password..."
        openssl rand -base64 32 > "$ENCRYPTION_PASSWORD_FILE"
        chmod 600 "$ENCRYPTION_PASSWORD_FILE"
        warn "New encryption password generated. Keep this file secure!"
    fi
}

# Create backup archive
create_backup() {
    log "Creating backup archive..."
    
    cd "$PROJECT_ROOT"
    
    # Create temporary backup
    local temp_backup="$BACKUP_DIR/temp/${BACKUP_NAME}.tar.gz"
    
    tar --exclude='./backups' \
        --exclude='./.git' \
        --exclude='./node_modules' \
        --exclude='./*.log' \
        --exclude='./docker/*/config' \
        --exclude='./docker/*/data' \
        --exclude='./docker/*/logs' \
        -czf "$temp_backup" .
    
    if [ "$ENCRYPT" = true ]; then
        log "Encrypting backup..."
        local encrypted_backup="$BACKUP_DIR/encrypted/${BACKUP_NAME}.tar.gz.enc"
        
        openssl enc -aes-256-cbc \
            -salt \
            -in "$temp_backup" \
            -out "$encrypted_backup" \
            -pass file:"$ENCRYPTION_PASSWORD_FILE"
        
        rm "$temp_backup"
        echo "$encrypted_backup"
    else
        mv "$temp_backup" "$BACKUP_DIR/"
        echo "$BACKUP_DIR/${BACKUP_NAME}.tar.gz"
    fi
}

# Backup to Proton Drive
backup_to_proton_drive() {
    if [ "$PROTON_DRIVE_BACKUP" != true ]; then
        return
    fi
    
    log "Backing up to Proton Drive..."
    
    # Check if rclone is configured for Proton Drive
    if ! rclone listremotes | grep -q "proton:"; then
        warn "Proton Drive not configured in rclone. Skipping cloud backup."
        warn "To configure: rclone config"
        return
    fi
    
    local backup_file="$1"
    local remote_path="proton:homelab-backups/"
    
    # Upload to Proton Drive
    if rclone copy "$backup_file" "$remote_path" --progress; then
        success "Backup uploaded to Proton Drive successfully"
    else
        error "Failed to upload backup to Proton Drive"
    fi
}

# Backup to GitHub
backup_to_github() {
    if [ "$GITHUB_BACKUP" != true ]; then
        return
    fi
    
    log "Backing up to GitHub..."
    
    # Check if git is configured
    if [ ! -d "$PROJECT_ROOT/.git" ]; then
        warn "Not a git repository. Skipping GitHub backup."
        return
    fi
    
    # Create backup branch
    local backup_branch="backup-${TIMESTAMP}"
    cd "$PROJECT_ROOT"
    
    # Stash any changes
    git stash push -m "Backup before creating backup branch" || true
    
    # Create and switch to backup branch
    git checkout -b "$backup_branch" || git checkout "$backup_branch"
    
    # Add backup files
    git add -A
    git commit -m "Backup: ${TIMESTAMP}" || warn "No changes to commit"
    
    # Push to GitHub
    if git push origin "$backup_branch"; then
        success "Backup branch pushed to GitHub: $backup_branch"
        
        # Clean up local backup branch
        git checkout main || git checkout master
        git branch -D "$backup_branch"
    else
        error "Failed to push backup branch to GitHub"
        warn "Backup branch remains locally: $backup_branch"
    fi
    
    # Restore stashed changes
    git stash pop || true
}

# Cleanup old backups
cleanup_old_backups() {
    log "Cleaning up old backups (older than $RETENTION_DAYS days)..."
    
    # Clean local backups
    find "$BACKUP_DIR" -name "*.tar.gz*" -mtime +$RETENTION_DAYS -delete 2>/dev/null || true
    
    # Clean GitHub backup branches (older than retention period)
    if [ "$GITHUB_BACKUP" = true ] && [ -d "$PROJECT_ROOT/.git" ]; then
        cd "$PROJECT_ROOT"
        local cutoff_date=$(date -d "$RETENTION_DAYS days ago" +%Y-%m-%d)
        
        # List old backup branches
        git branch -r | grep "origin/backup-" | while read branch; do
            local branch_date=$(git log -1 --format=%cd --date=short "$branch" 2>/dev/null)
            if [[ "$branch_date" < "$cutoff_date" ]]; then
                local branch_name=$(echo "$branch" | sed 's/origin\///')
                log "Deleting old backup branch: $branch_name"
                git push origin --delete "$branch_name" 2>/dev/null || warn "Failed to delete remote branch: $branch_name"
            fi
        done
    fi
    
    success "Cleanup completed"
}

# Verify backup integrity
verify_backup() {
    local backup_file="$1"
    log "Verifying backup integrity..."
    
    if [ "$ENCRYPT" = true ]; then
        # Test decryption
        if openssl enc -d -aes-256-cbc \
            -in "$backup_file" \
            -out /dev/null \
            -pass file:"$ENCRYPTION_PASSWORD_FILE" 2>/dev/null; then
            success "Encrypted backup verified successfully"
        else
            error "Backup verification failed - decryption error"
            return 1
        fi
    else
        # Test archive integrity
        if tar -tzf "$backup_file" > /dev/null; then
            success "Backup archive verified successfully"
        else
            error "Backup verification failed - archive corruption"
            return 1
        fi
    fi
}

# Main backup process
main() {
    log "Starting enhanced backup process..."
    
    # Check dependencies
    check_dependencies
    
    # Setup
    setup_directories
    setup_encryption
    
    # Create backup
    local backup_file
    backup_file=$(create_backup)
    
    if [ -z "$backup_file" ]; then
        error "Failed to create backup"
        exit 1
    fi
    
    # Verify backup
    if ! verify_backup "$backup_file"; then
        error "Backup verification failed"
        exit 1
    fi
    
    # Cloud backups
    backup_to_proton_drive "$backup_file"
    backup_to_github
    
    # Cleanup
    cleanup_old_backups
    
    # Final status
    local backup_size=$(du -h "$backup_file" | cut -f1)
    success "Backup completed successfully!"
    log "Backup file: $backup_file"
    log "Backup size: $backup_size"
    log "Backup timestamp: $TIMESTAMP"
    
    # Cleanup temporary files
    rm -rf "$BACKUP_DIR/temp"/*
}

# Handle script interruption
trap 'error "Backup interrupted"; exit 1' INT TERM

# Run main function
main "$@"
