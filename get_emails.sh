#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# UChicago

# sample files for testing
export CSV_FILE="${CSV_FILE:-email/uchicago_emailencrypted_sample.csv}"
export OUTPUT_CSV_FILE="${OUTPUT_CSV_FILE:-email/uchicago_extracted_emails_sample.csv}"

# # actual list of encrypted emails to process
# export CSV_FILE="${CSV_FILE:-email/uchicago_emailencrypted.csv}"
# export OUTPUT_CSV_FILE="${OUTPUT_CSV_FILE:-email/uchicago_extracted_emails.csv}"

export BASE_PROFILE_PREFIX="${BASE_PROFILE_PREFIX:-https://profiles.uchicago.edu/profiles/profile/}"
export EMAIL_HANDLER_URL="${EMAIL_HANDLER_URL:-https://profiles.uchicago.edu/profiles/profile/modules/CustomViewPersonGeneralInfo/EmailHandler.ashx}"

# Rush

# # sample files for testing
# export CSV_FILE="${CSV_FILE:-email/rush_emailencrypted_sample.csv}"
# export OUTPUT_CSV_FILE="${OUTPUT_CSV_FILE:-email/rush_extracted_emails_sample.csv}"

# # actual list of encrypted emails to process
# export CSV_FILE="${CSV_FILE:-email/rush_emailencrypted.csv}"
# export OUTPUT_CSV_FILE="${OUTPUT_CSV_FILE:-email/rush_extracted_emails.csv}"

# export BASE_PROFILE_PREFIX="${BASE_PROFILE_PREFIX:-https://profiles.rush.edu/profile/}"
# export EMAIL_HANDLER_URL="${EMAIL_HANDLER_URL:-https://profiles.rush.edu/profile/modules/CustomViewPersonGeneralInfo/EmailHandler.ashx}"


echo "Running get_emails.py with:"
echo "  CSV_FILE=$CSV_FILE"
echo "  OUTPUT_CSV_FILE=$OUTPUT_CSV_FILE"

cd "$SCRIPT_DIR"
python3 get_emails.py
