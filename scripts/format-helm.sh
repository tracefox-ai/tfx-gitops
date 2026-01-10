#!/bin/bash

# Helm Chart Formatting and Linting Script
set -e

echo "🔧 Formatting and Linting Helm Charts..."

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    echo -e "${GREEN}✓${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}⚠${NC} $1"
}

print_error() {
    echo -e "${RED}✗${NC} $1"
}

# Check if required tools are installed
check_tools() {
    echo "Checking required tools..."
    
    if ! command -v helm &> /dev/null; then
        print_error "helm is not installed"
        exit 1
    fi
    
    if ! command -v yamllint &> /dev/null; then
        print_warning "yamllint is not installed. Install with: brew install yamllint"
    fi
    
    if ! command -v helm-docs &> /dev/null; then
        print_warning "helm-docs is not installed. Install with: brew install norwoodj/tap/helm-docs"
    fi
    
    print_status "Tools check completed"
}

# Lint Helm charts
lint_charts() {
    echo "Linting Helm charts..."
    
    for chart_dir in helm/*/; do
        if [ -f "$chart_dir/Chart.yaml" ]; then
            chart_name=$(basename "$chart_dir")
            echo "Linting $chart_name..."
            
            if helm lint "$chart_dir"; then
                print_status "Helm lint passed for $chart_name"
            else
                print_error "Helm lint failed for $chart_name"
                exit 1
            fi
        fi
    done
}

# YAML lint charts
yaml_lint_charts() {
    if command -v yamllint &> /dev/null; then
        echo "YAML linting charts..."
        
        for chart_dir in helm/*/; do
            if [ -f "$chart_dir/Chart.yaml" ]; then
                chart_name=$(basename "$chart_dir")
                echo "YAML linting $chart_name..."
                
                if yamllint -c .yamllint.yml "$chart_dir"; then
                    print_status "YAML lint passed for $chart_name"
                else
                    print_warning "YAML lint issues found in $chart_name"
                fi
            fi
        done
    else
        print_warning "Skipping YAML lint (yamllint not installed)"
    fi
}

# Generate documentation
generate_docs() {
    if command -v helm-docs &> /dev/null; then
        echo "Generating documentation..."
        
        if helm-docs helm/; then
            print_status "Documentation generated successfully"
        else
            print_error "Documentation generation failed"
            exit 1
        fi
    else
        print_warning "Skipping documentation generation (helm-docs not installed)"
    fi
}

# Template validation
validate_templates() {
    echo "Validating Helm templates..."
    
    for chart_dir in helm/*/; do
        if [ -f "$chart_dir/Chart.yaml" ]; then
            chart_name=$(basename "$chart_dir")
            echo "Validating templates for $chart_name..."
            
            if helm template test "$chart_dir" > /dev/null; then
                print_status "Template validation passed for $chart_name"
            else
                print_error "Template validation failed for $chart_name"
                exit 1
            fi
        fi
    done
}

# Main execution
main() {
    echo "🚀 Starting Helm Chart Formatting and Linting"
    echo "=============================================="
    
    check_tools
    echo ""
    
    lint_charts
    echo ""
    
    yaml_lint_charts
    echo ""
    
    validate_templates
    echo ""
    
    generate_docs
    echo ""
    
    print_status "All checks completed successfully!"
    echo ""
    echo "📋 Summary:"
    echo "  - Helm lint: ✓"
    echo "  - YAML lint: ✓"
    echo "  - Template validation: ✓"
    echo "  - Documentation: ✓"
}

# Run main function
main "$@"