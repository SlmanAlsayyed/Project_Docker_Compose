#!/bin/bash

# Create a main results directory with timestamp
main_results_dir="scan_results_$(date +%Y%m%d_%H%M%S)"
mkdir -p "$main_results_dir"

echo "Scanning started at $(date)"

# Get list of Docker images and process each one
docker images --format '{{.Repository}}:{{.Tag}}' | sort -u | while read -r image; do
    # Replace invalid filename characters (like /) with _
    safe_image_name=$(echo "$image" | tr '/' '_')
    
    # Create a directory for this specific image
    image_dir="$main_results_dir/$safe_image_name"
    mkdir -p "$image_dir"
    
    # Define output files within the image directory
    high_file="$image_dir/HIGH.txt"
    medium_file="$image_dir/MEDIUM.txt"
    low_file="$image_dir/LOW.txt"
    log_file="$image_dir/scan_log.txt"
    
    # Clear or create the files
    > "$high_file"
    > "$medium_file"
    > "$low_file"
    > "$log_file"
    
    echo "Checking if $image is available locally..." | tee -a "$log_file"
    
    # Try to pull the image if it's not already on the system
    if ! docker images "$image" > /dev/null 2>&1; then
        echo "$image not found locally. Pulling image..." | tee -a "$log_file"
        docker pull "$image" >> "$log_file" 2>&1
    fi
    
    echo "Scanning $image..." | tee -a "$log_file"
    
    # Scan for each severity level directly using Trivy --severity
    echo "Scan results for $image - HIGH severity" > "$high_file"
    echo "=====================================" >> "$high_file"
    trivy image --severity HIGH,CRITICAL "$image" >> "$high_file" 2>> "$log_file" || echo "No HIGH/CRITICAL vulnerabilities found" >> "$high_file"
    
    echo "Scan results for $image - MEDIUM severity" > "$medium_file"
    echo "=====================================" >> "$medium_file"
    trivy image --severity MEDIUM "$image" >> "$medium_file" 2>> "$log_file" || echo "No MEDIUM vulnerabilities found" >> "$medium_file"
    
    echo "Scan results for $image - LOW severity" > "$low_file"
    echo "=====================================" >> "$low_file"
    trivy image --severity LOW "$image" >> "$low_file" 2>> "$log_file" || echo "No LOW vulnerabilities found" >> "$low_file"
    
    echo "Completed scanning $image - Results saved in $image_dir/"
    echo "-----------------------------"
done

echo "Scanning completed at $(date)"
echo "All results are stored in $main_results_dir/"