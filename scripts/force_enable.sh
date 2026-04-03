#!/bin/bash

# STRIPE CONNECT SANDBOX FORCE-ENABLE SCRIPT (V5 - Sanitized)
# Targets: acct_1TAOvt29Bf5Kd5v4

# 1. GET VARIABLES VIA PROMPT (To avoid GitHub Secret Scanning)
read -p "Enter your Stripe Secret Key (sk_test_...): " SECRET_KEY
ACCOUNT_ID="acct_1TAOvt29Bf5Kd5v4"

if [ -z "$SECRET_KEY" ]; then
    echo "Error: Secret Key is required."
    exit 1
fi

echo "Step 1: Satisfying 'Proof of Registration' (Company Level)..."
curl -s https://api.stripe.com/v1/accounts/$ACCOUNT_ID \
  -u $SECRET_KEY: \
  -d "company[verification][document][front]"="tok_ca" \
  -d "company[verification][document][back]"="tok_ca" \
  -d "company[tax_id]"="000000000" \
  -d "company[structure]"="private_corporation" \
  -d "business_profile[mcc]"="5921" \
  -d "business_profile[url]"="www.alleykat.ca" > /dev/null

echo "Step 2: Identifying Representative..."
PERSON_ID=$(curl -s https://api.stripe.com/v1/accounts/$ACCOUNT_ID/persons -u $SECRET_KEY: | grep -oE 'person_[a-zA-Z0-9]+' | head -n 1)

if [ -z "$PERSON_ID" ]; then
    echo "No Person ID found. Creating representative..."
    PERSON_ID=$(curl -s https://api.stripe.com/v1/accounts/$ACCOUNT_ID/persons \
      -u $SECRET_KEY: \
      -d "first_name"="Allie" \
      -d "last_name"="Katz" \
      -d "relationship[representative]"=true \
      -d "relationship[director]"=true \
      -d "relationship[executive]"=true \
      -d "relationship[owner]"=true \
      -d "relationship[title]"="Director" | grep -oE 'person_[a-zA-Z0-9]+' | head -n 1)
else
    curl -s https://api.stripe.com/v1/accounts/$ACCOUNT_ID/persons/$PERSON_ID \
      -u $SECRET_KEY: \
      -d "relationship[director]"=true \
      -d "relationship[executive]"=true \
      -d "relationship[owner]"=true \
      -d "relationship[percent_ownership]"=100 > /dev/null
fi

echo "Step 3: Clearing Representative KYC..."
curl -s https://api.stripe.com/v1/accounts/$ACCOUNT_ID/persons/$PERSON_ID \
  -u $SECRET_KEY: \
  -d "verification[document][front]"="tok_ca" \
  -d "verification[additional_document][front]"="tok_ca" \
  -d "address[line1]"="1234 99 Street NW" \
  -d "address[city]"="Edmonton" \
  -d "address[state]"="AB" \
  -d "address[postal_code]"="T6N 0A8" \
  -d "address[country]"="CA" > /dev/null

echo "Step 4: Finalizing Capabilities & TOS..."
curl -s https://api.stripe.com/v1/accounts/$ACCOUNT_ID \
  -u $SECRET_KEY: \
  -d "capabilities[card_payments][requested]"=true \
  -d "capabilities[transfers][requested]"=true \
  -d "tos_acceptance[date]"=$(date +%s) \
  -d "tos_acceptance[ip]"="127.0.0.1" > /dev/null

echo -e "\n--- DIAGNOSTIC CHECK ---"
STATUS=$(curl -s https://api.stripe.com/v1/accounts/$ACCOUNT_ID -u $SECRET_KEY:)
CHARGES=$(echo $STATUS | grep -o '"charges_enabled":[^,]*' | cut -d: -f2 | tr -d ' "')
echo "Account ID: $ACCOUNT_ID"
echo "Charges Enabled: $CHARGES"

if [ "$CHARGES" == "true" ]; then
    echo -e "\nSUCCESS: Charges are ENABLED."
fi