#!/bin/bash

CONFIG_FILE="$HOME/influx_auth.conf"

# Load stored credentials if file exists
if [[ -f "$CONFIG_FILE" ]]; then
    source "$CONFIG_FILE"
    USE_SAVED_CREDENTIALS=true
else
    USE_SAVED_CREDENTIALS=false
fi

# Function to authenticate manually
function setup_auth() {
    echo -e "\n🔑 Setting up InfluxDB authentication...\n"
    
    read -p "Enter InfluxDB URL (default: http://localhost:8086): " INFLUX_URL
    INFLUX_URL=${INFLUX_URL:-"http://localhost:8086"}

    read -p "Enter your admin username: " INFLUX_USER
    read -s -p "Enter your password: " INFLUX_PASS
    echo ""

    read -p "Enter your organization name: " INFLUX_ORG

    # Offer to save credentials
    echo -e "\n💾 Do you want to save credentials for auto-login? (y/n)"
    read -r SAVE_CREDS
    if [[ "$SAVE_CREDS" =~ ^[Yy]$ ]]; then
        echo -e "INFLUX_URL=$INFLUX_URL\nINFLUX_USER=$INFLUX_USER\nINFLUX_PASS=$INFLUX_PASS\nINFLUX_ORG=$INFLUX_ORG" > "$CONFIG_FILE"
        chmod 600 "$CONFIG_FILE"
        echo -e "\n✅ Credentials saved in $CONFIG_FILE (secured with chmod 600)"
    fi

    echo -e "\n✅ Authentication completed!\n"
}

function show_credentials_disclaimer() {
	echo -e "This program stores the credential variables in a file called: influx_auth.conf"
    echo
    echo "INFLUX_URL=http://<influx_host_ip>:8086/"
    echo "INFLUX_USER=<admin_user>"
    echo "INFLUX_PASS=<influx_admin_password>"
    echo "INFLUX_ORG=<organization_name>"
    echo
    echo "You can edit this file to change the credentials at anytime."
	
}

# Validate credentials by listing organizations (ensures access)
function validate_login() {
    echo -e "\n🔍 Validating credentials..."
    ORG_CHECK=$(influx org list --json 2>&1)
    
    if echo "$ORG_CHECK" | grep -q "Unauthorized"; then
        echo -e "❌ Invalid credentials! Please re-enter authentication details.\n"
        USE_SAVED_CREDENTIALS=false
        setup_auth
        show_credentials_disclaimer
        echo
        read -p "Press enter to continue: " enter
    else
        echo
        echo -e "✅ Login successful!\n"
        show_credentials_disclaimer
        echo
        read -p "Press enter to continue: " enter
		
    fi
}

# List all buckets (databases) with readable output
function list_buckets() {
    echo -e "\n📦 Showing all bucket list info..."
    influx bucket list --json | jq -r
    echo
    read -p "Press enter to show only the Buckets (databases): " enter
    echo -e "\n📂 Available Buckets (Databases):\n"
    influx bucket list --json | jq -r '.[] | "📂 Name: \(.name) | ID: \(.id) | Retention: \(.retentionPeriodSeconds) seconds"'
    echo
    read -p "Press enter to continue to main menu: " enter
}

# List all organizations
function list_orgs() {
    echo -e "\n🏢 Showing all organization list info..."
    influx org list --json | jq -r
    echo
    read -p "Press enter to show only the Organizations: " enter
    echo -e "\n🏢 Organizations:\n"
    influx org list --json | jq -r '.[] | "🏢 Name: \(.name) | ID: \(.id)"'
    echo
    read -p "Press enter to continue: " enter
}

# List all users
function list_users() {
    echo -e "\n👤 Showing all users list info..."
    influx user list --json | jq -r
    echo
    read -p "Press enter to show only the Users and their ids: " enter
    echo -e "\n👤 Users:\n"
    influx user list --json | jq -r '.[] | "👤 Name: \(.name) | ID: \(.id)"'
    echo
    read -p "Press enter to continue: " enter
}

function list_users_detail() {
	echo -e "\n👤 Showing all users detailed list info for organization $INFLUX_ORG..."
	influx auth list --json | jq
	echo
    read -p "Press enter to continue to main menu: " enter
}

# Create a new bucket (database)
function create_bucket() {
    echo -e "\n➕ Create a new database (bucket):\n"
    read -p "Enter bucket name: " BUCKET_NAME
    read -p "Enter retention period in hours (0 for infinite): " RETENTION_HOURS
    RETENTION_SECONDS=$((RETENTION_HOURS * 3600))

    influx bucket create --name "$BUCKET_NAME" --org "$INFLUX_ORG" --retention "$RETENTION_SECONDS"
    
    echo -e "\n✅ Bucket '$BUCKET_NAME' created successfully!\n"
    echo
    read -p "Press enter to continue to main menu: " enter
}

# Delete a bucket (database)
function delete_bucket() {
    list_buckets
    echo -e "\n❌ Showing all bucket list info before deletion..."
    influx bucket list --json | jq -r
    echo
    read -p "Press enter to show only the Bucket IDs before deletion: " enter
    echo -e "\n📦 Available Buckets (Databases):\n"
    influx bucket list --json | jq -r '.[] | "📂 Name: \(.name) | ID: \(.id) | Retention: \(.retentionPeriodSeconds) seconds"'
    
    echo -e "\n❌ Delete a bucket (database):\n"
    read -p "Enter the Bucket ID to delete: " BUCKET_ID
    influx bucket delete --id "$BUCKET_ID"

    echo -e "\n✅ Bucket deleted successfully!\n"
    echo
    read -p "Press enter to continue to main menu: " enter
}

# Query a bucket interactively
function query_bucket() {
    list_buckets
    echo -e "\n🔍 Query a bucket (database):\n"
    read -p "Enter bucket name to query: " BUCKET_NAME
    read -p "Enter Flux query (e.g., 'from(bucket:\"$BUCKET_NAME\") |> range(start: -1h)'): " FLUX_QUERY

    influx query --org "$INFLUX_ORG" --raw "$FLUX_QUERY"

    echo -e "\n✅ Query executed!\n"
    echo
    read -p "Press enter to continue to main menu: " enter
}

# Add a new user with all privileges
function add_user() {
    echo -e "\n👤 Add a new user with all privileges:\n"
    read -p "Enter new username: " USERNAME
    read -p "Enter new user password: " PASSWORD
    read -p "Enter organization name: " ORG_NAME
    
    influx user create --name "$USERNAME" --password "$PASSWORD" --org "$ORG_NAME"
    
    echo -e "\n🔑 Assigning all privileges to user '$USERNAME'...\n"
    #influx auth create --user "$USERNAME" --org "$ORG_NAME" --all-access
    influx auth create --user "$USERNAME" --org "$ORG_NAME" --read-buckets --write-buckets --read-dashboards --write-dashboards --read-orgs --read-sources --write-sources --read-tasks --write-tasks --read-telegrafs --write-telegrafs --read-variables --write-variables --read-scrapers --write-scrapers --read-secrets --write-secrets --read-labels --write-labels --read-views --write-views --read-documents --write-documents --read-notificationRules --write-notificationRules --read-notificationEndpoints --write-notificationEndpoints --read-checks --write-checks --read-dbrp --write-dbrp --read-notebooks --write-notebooks --read-annotations --write-annotations --read-remotes --write-remotes --read-replications --write-replications

    echo -e "\n✅ User '$USERNAME' created with full privileges!\n"
    echo
    read -p "Press enter to continue to main menu: " enter
}

# Delete an existing user
function delete_user() {
    echo -e "\n❌ Delete an existing user:\n"

    # List all users first
    list_users

    echo -e "\n🔍 Please enter the username ID to delete:\n"
    read -p "Username: " USERID

    # Confirm before deletion
    read -p "⚠️ Are you sure you want to delete user '$USERNAME'? (y/n): " CONFIRM
    if [[ "$CONFIRM" =~ ^[Yy]$ ]]; then
        influx user delete --id "$USERID"
        echo -e "\n✅ User '$USERNAME' deleted successfully!\n"
    else
        echo -e "\n❌ Operation canceled.\n"
    fi
    echo
    read -p "Press enter to continue to main menu: " enter
}


# Create a new organization
function create_org() {
    echo -e "\n🏢 Create a new organization:\n"
    read -p "Enter new organization name: " NEW_ORG
    influx org create --name "$NEW_ORG"
    echo -e "\n✅ Organization '$NEW_ORG' created successfully!\n"
    echo
    read -p "Press enter to continue to main menu: " enter
}

#!/bin/bash

# Function to list all measurements in a given bucket
function influx_query_show_measurements() {
    echo
    read -p "Provide a valid organization name: " organization_name
    [[ -z "$organization_name" ]] && { echo "❌ Organization name cannot be empty."; return 1; }

    echo
    read -p "Now type the bucket name (database name) to view measurements: " bucket_name
    [[ -z "$bucket_name" ]] && { echo "❌ Bucket name cannot be empty."; return 1; }

    echo
    echo -e "📊 Listing measurements for bucket: $bucket_name\n"
    influx query --org "$organization_name" --raw 'import "influxdata/influxdb/schema" schema.measurements(bucket: "'$bucket_name'")'
    echo
    read -p "Press enter to return to return to the menu: " enter
}

# Function to delete a specific measurement from a bucket
function influx_delete_measurement() {
    echo
    read -p "Provide the organization name: " organization_name
    [[ -z "$organization_name" ]] && { echo "❌ Organization name cannot be empty."; return 1; }

    echo
    read -p "Enter the bucket name: " bucket_name
    [[ -z "$bucket_name" ]] && { echo "❌ Bucket name cannot be empty."; return 1; }

    echo
    read -p "Enter the measurement name to delete: " measurement_name
    [[ -z "$measurement_name" ]] && { echo "❌ Measurement name cannot be empty."; return 1; }

    echo
    echo -e "🗑️ Deleting measurement: $measurement_name from bucket: $bucket_name"
    influx delete --org "$organization_name" --bucket "$bucket_name" --predicate '_measurement="'"$measurement_name"'"' --start 1970-01-01T00:00:00Z --stop $(date -u +"%Y-%m-%dT%H:%M:%SZ")
    echo
    read -p "Press enter to return to return to the menu: " enter
}

# Function to create a new measurement in a bucket
function influx_create_measurement() {
    echo
    read -p "Provide the organization name: " organization_name
    [[ -z "$organization_name" ]] && { echo "❌ Organization name cannot be empty."; return 1; }

    echo
    read -p "Enter the bucket name: " bucket_name
    [[ -z "$bucket_name" ]] && { echo "❌ Bucket name cannot be empty."; return 1; }

    echo
    read -p "Enter the measurement name: " measurement_name
    [[ -z "$measurement_name" ]] && { echo "❌ Measurement name cannot be empty."; return 1; }

    echo
    read -p "Enter the field key: " field_key
    [[ -z "$field_key" ]] && { echo "❌ Field key cannot be empty."; return 1; }

    echo
    read -p "Enter the field value (number or string): " field_value
    [[ -z "$field_value" ]] && { echo "❌ Field value cannot be empty."; return 1; }

    echo
    read -p "Enter the tag key (optional, press Enter to skip): " tag_key
    read -p "Enter the tag value (optional, press Enter to skip): " tag_value

    data="$measurement_name"
    [[ -n "$tag_key" && -n "$tag_value" ]] && data+=",${tag_key}=${tag_value}"
    data+=" ${field_key}=${field_value}"

    echo -e "📝 Writing measurement: $measurement_name into bucket: $bucket_name"
    influx write --org "$organization_name" --bucket "$bucket_name" --precision s "$data"
    echo
    read -p "Press enter to return to return to the menu: " enter
}

function validate_buketip_token() {
	echo
	read -p "Provide the INFLUXDB host ip address: " host_ip
	echo
	read -p "Now provide a token to validate with influx, and collect data: " token_value
	echo -e "Running curl call to http://$host_ip:8086/api/v2/authorizations..."
	curl -X GET "http://$host_ip:8086/api/v2/authorizations" --header "Authorization: Token $token_value" --header "Content-Type: application/json"
	echo
    read -p "Press enter to return to return to the menu: " enter

}

function influx_queries() {
	while true; do
	
		echo -e "\n========= 📦 InfluxDB CLI QUERIES Menu =========\n"
		echo "1 - Validate authentication with ip bucket name, and token"
		echo "2 - Show all measurements in a bucket (database)"
		echo "3 - Create a measurement in a bucket"
		echo "4 - Delete a measurment in a bucket (databse)"
		echo "5 - Back to main menu"
		echo -e "\n========================================\n"

		read -p "Select an option: " OPTION
		case $OPTION in
		
		    1)
		        validate_buketip_token ;;
			2)  
			    influx_query_show_measurements ;;
			3)  
			    influx_create_measurement ;;			
			4)  
			    influx_delete_measurement ;;
			5)  
			    main_menu ;;
			    
			*) echo -e "\n⚠️  Invalid option, please try again.\n" ;;
		esac
	done
}
# Other functions remain unchanged...

# Show the main menu
function main_menu() {
    while true; do
        echo -e "\n========= 📡 InfluxDB CLI Menu =========\n"
        echo -e "🏢 **Organizations**\n   - Group users, databases (buckets), and permissions together.\n"
		echo -e "📦 **Buckets (Databases)**\n   - Store time-series data, associated with an organization.\n"
		echo -e "👤 **Users**\n   - Belong to organizations and have specific roles/permissions.\n"
        echo "1 - List Buckets (Databases)"
        echo "2 - List Organizations"
        echo "3 - List Users"
        echo "4 - List Users Detialed | Lists users with all their info"
        echo "5 - Create a New Database (Bucket)"
        echo "6 - Delete a Database (Bucket)"
        echo "7 - Query a Database (Bucket)"
        echo "8 - Add a New Admin User"
        echo "9 - Delete a User"
        echo "10 - Create a New Organization"
        echo "11 - Delete an Organization"
        echo "----------------------------------------------------------"
        echo "12 - INFLUX QUERIES MENU"
        echo "----------------------------------------------------------"
        echo "13 - Exit"
        echo -e "\n========================================\n"

        read -p "Select an option: " OPTION
        case $OPTION in
            1) list_buckets ;;
            2) list_orgs ;;
            3) list_users ;;
            4) list_users_detail ;;
            5) create_bucket ;;
            6) delete_bucket ;;
            7) query_bucket ;;
            8) add_user ;;
            9) delete_user ;;
            10) create_org ;;
            11) delete_org ;;
            12) influx_queries ;;
            13) echo -e "\n👋 Exiting...\n"; exit 0 ;;
            *) echo -e "\n⚠️  Invalid option, please try again.\n" ;;
        esac
    done
}

# Start the script
if [[ "$USE_SAVED_CREDENTIALS" == true ]]; then
    echo -e "\n🔑 Using saved credentials...\n"
else
    setup_auth
fi

validate_login
main_menu
