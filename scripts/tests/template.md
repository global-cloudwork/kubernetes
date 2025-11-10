# Robust Bash Script Template

This template emphasizes clear **metadata**, defined **error codes**, and **robust function design** that returns specific exit statuses for predictable error handling in a larger pipeline.

```bash
#!/bin/bash

# ==============================================================================
# SCRIPT METADATA
# ==============================================================================
# Filename:   script_name.sh
# Purpose:    A generic template demonstrating robust function design with
#             specific error return codes and clear argument handling.
# Author:     Your Name
# Date:       2025-11-09
# Version:    1.0.0
# License:    MIT / GPL (Specify one or remove)

# --- Configuration ---
# Set strict error handling:
# -e: Exit immediately if a command exits with a non-zero status.
# -u: Treat unset variables as an error.
# -o pipefail: The return value of a pipeline is the status of the last command
#              to exit with a non-zero status, or zero if all commands exit
#              successfully.
set -euo pipefail
# set -x # Uncomment for debugging

# ==============================================================================
# ERROR CODES (Define status codes for clear communication)
# ==============================================================================
# 0 - Success (Standard UNIX exit status)
# 1 - Generic/Unknown Error (Reserved for unforeseen issues)
# 2 - Invalid Input/Argument Error (Missing or improperly formatted arguments)
# 3 - Dependency Not Found (e.g., missing utility like 'jq' or 'curl')
# 4 - Operation Failed (A specific action like file write/read or API call failed)
# 5 - Permission Denied (e.g., inability to write to a required directory)

# ==============================================================================
# FUNCTION: func_inner
# ==============================================================================
# Purpose:    Performs a specific, isolated task (simulating processing).
# Arguments:  $1 - A required input string (must be non-empty).
# Output:     Standard output messages/data (only if successful). Error messages
#             are sent to stderr (>&#38;2).
# Returns:    An integer status code (0 for success, >0 for specific errors).
func_inner() {
    # Localize variables to prevent side effects in the global scope
    local input_value="$1"
    local dependency_check="echo" # Example dependency to check
    local length=0

    # 1. Check for Invalid Input (Error Code 2)
    if [ -z "$input_value" ]; then
        echo "ERROR (2): Missing required input value. Cannot proceed without \$1." >&2
        return 2
    fi
    
    # 2. Check for Dependency (Error Code 3)
    if ! command -v "$dependency_check" &> /dev/null; then
        echo "ERROR (3): Required utility '$dependency_check' not found." >&2
        return 3
    fi

    # 3. Simulate Operation Failure (Error Code 4)
    # If the input is exactly "critical_fail", return a specific failure code.
    if [ "$input_value" == "critical_fail" ]; then
        echo "ERROR (4): Simulated critical operation failure for input '$input_value'." >&2
        return 4
    fi

    # 4. Success Case (Return Code 0)
    length=${#input_value}
    echo "INFO: Successfully validated and processed input: '$input_value'"
    echo "RESULT: Input string length is: $length characters."
    
    return 0
}

# ==============================================================================
# MAIN SCRIPT EXECUTION AND DEMONSTRATION
# ==============================================================================

echo "--- Demonstration of func_inner ---"

# Test Case A: Success (Expected Status: 0)
echo -e "\n[TEST A] Running func_inner with 'ExampleString'"
func_inner "ExampleString"
result_A=$?
echo "--> Last Exit Status: $result_A"

# Test Case B: Invalid Input (Missing argument, Expected Status: 2)
echo -e "\n[TEST B] Running func_inner with no argument"
# Use || true to prevent 'set -e' from exiting the entire script
# when the function fails as expected. We can still capture the status.
func_inner "" || true
result_B=$?
echo "--> Last Exit Status: $result_B"


# Test Case C: Operation Failed (Simulated failure, Expected Status: 4)
echo -e "\n[TEST C] Running func_inner with 'critical_fail'"
func_inner "critical_fail" || true
result_C=$?
echo "--> Last Exit Status: $result_C"


# ==============================================================================
# SUMMARY OUTPUT AND FINAL EXIT
# ==============================================================================
echo -e "\n--- Summary of Execution ---"
echo "Test A (Success): Status Code $result_A (Expected: 0)"
echo "Test B (Missing Arg): Status Code $result_B (Expected: 2 - Invalid Input/Argument Error)"
echo "Test C (Operation Fail): Status Code $result_C (Expected: 4 - Operation Failed)"

# Exit the main script cleanly
exit 0