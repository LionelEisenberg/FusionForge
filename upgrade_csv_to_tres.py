import csv
import os
import re

# --- CONFIGURATION ---
CSV_FILE_PATH = 'Balancing Sheet - Upgrade Definitions.csv' # Ensure this is your correct CSV file name
GODOT_UPGRADES_PATH = './resources/upgrades/'

# --- HELPER FUNCTIONS (clean_effect_value and update_tres_file remain the same as v3) ---
def clean_effect_value(effect_str):
    """Cleans the effect string from CSV (e.g., 'x1.1', '-0.5', 'Unlocks h_h_to_he')
       and attempts to convert to float if numeric, otherwise returns as string."""
    effect_str = effect_str.strip()
    if effect_str.lower().startswith('x'):
        try:
            return float(effect_str[1:])
        except ValueError:
            print(f"Warning: Could not convert multiplier {effect_str} to float.")
            return effect_str
    elif effect_str.lower().startswith('unlocks '):
        recipe_name = effect_str[len('unlocks '):].strip()
        if not (recipe_name.startswith('"') and recipe_name.endswith('"')):
            recipe_name = f'"{recipe_name}"'
        return recipe_name
    else:
        try:
            return float(effect_str)
        except ValueError:
            # For other non-numeric strings that aren't unlocks, return them as is.
            # The update_tres_file function will handle quoting if necessary.
            return effect_str


def update_tres_file(tres_file_path, updates):
    """
    Reads a .tres file, updates specified properties, and writes it back.
    'updates' is a dictionary like {'property_name': new_value}
    """
    if not os.path.exists(tres_file_path):
        print(f"Error: .tres file not found: {tres_file_path}")
        return False 

    lines = []
    updated_something = False
    try:
        with open(tres_file_path, 'r', encoding='utf-8') as f:
            lines = f.readlines()
    except Exception as e:
        print(f"Error reading {tres_file_path}: {e}")
        return None 

    new_lines = []
    for line_content in lines:
        current_line_for_prop_update = line_content
        for prop_name, new_value in updates.items():
            pattern = re.compile(rf"^\s*{re.escape(prop_name)}\s*=\s*(.*)")
            match = pattern.match(current_line_for_prop_update)

            if match:
                current_value_str = match.group(1).strip()
                formatted_new_value = ""

                if isinstance(new_value, str):
                    if new_value.startswith('"') and new_value.endswith('"'):
                        formatted_new_value = new_value
                    elif new_value.lower() in ['true', 'false']:
                         formatted_new_value = new_value.lower()
                    else:
                         formatted_new_value = f'"{new_value}"'
                elif isinstance(new_value, bool):
                    formatted_new_value = str(new_value).lower()
                elif isinstance(new_value, (int, float)):
                    if isinstance(new_value, float) and new_value == int(new_value):
                        formatted_new_value = str(int(new_value))
                    elif isinstance(new_value, float):
                        formatted_new_value = f"{new_value:.6g}".rstrip('0').rstrip('.')
                        if not formatted_new_value or formatted_new_value == "-":
                            formatted_new_value = "0.0"
                        elif '.' not in formatted_new_value and 'e' not in formatted_new_value.lower():
                             formatted_new_value = f"{float(formatted_new_value):.1f}"
                    else: # int
                        formatted_new_value = str(new_value)
                else:
                    print(f"Warning: Unexpected type for new_value '{new_value}' (type: {type(new_value)}) for property '{prop_name}'. Using current value.")
                    formatted_new_value = current_value_str

                potential_new_line = f"{prop_name} = {formatted_new_value}\n"
                if potential_new_line.strip() != current_line_for_prop_update.strip():
                    current_line_for_prop_update = potential_new_line
                    updated_something = True
                break
        new_lines.append(current_line_for_prop_update)

    if updated_something:
        try:
            with open(tres_file_path, 'w', encoding='utf-8') as f:
                f.writelines(new_lines)
            return True
        except Exception as e:
            print(f"Error writing to {tres_file_path}: {e}")
            return None
    return False

# --- MAIN SCRIPT LOGIC ---
def main():
    if not os.path.exists(CSV_FILE_PATH):
        print(f"Error: CSV file not found at {CSV_FILE_PATH}")
        return

    if not os.path.isdir(GODOT_UPGRADES_PATH):
        print(f"Error: Godot upgrades directory not found at {GODOT_UPGRADES_PATH}")
        return

    print("Starting .tres file update process...")
    print(f"Reading from CSV: {CSV_FILE_PATH}")
    print(f"Updating .tres files in: {GODOT_UPGRADES_PATH}")
    print("-" * 30)

    all_upgrade_data_from_csv = {} # Store all parsed CSV data here

    with open(CSV_FILE_PATH, mode='r', encoding='utf-8-sig') as csvfile:
        try:
            next(csvfile)  # Skip the very first line (assumed to be a title/meta line)
            print("Skipped the first line of the CSV.")
        except StopIteration:
            print("Error: CSV file is empty or only had one line (could not skip first line).")
            return

        reader = csv.DictReader(csvfile)
        
        if not reader.fieldnames:
            print("Error: CSV file has no header row after skipping the first line, or is effectively empty.")
            return

        expected_headers = ['UpgradeId', 'Max Number of Levels', 'Base Money Cost',
                            'Base Money Cost Scaling', '.tres property', 'Effect per Level']
        missing_headers = [h for h in expected_headers if h not in reader.fieldnames]
        if missing_headers:
            print(f"Error: CSV file is missing expected headers: {', '.join(missing_headers)}")
            print(f"  Detected headers: {reader.fieldnames}")
            return

        for row_num, row in enumerate(reader, 2): # Start row_num from 2
            try:
                upgrade_id = row.get('UpgradeId', '').strip()
                if not upgrade_id:
                    print(f"Warning: Skipping CSV row {row_num} due to missing UpgradeId.")
                    continue

                # If UpgradeId is not yet in our dictionary, add it with basic properties
                if upgrade_id not in all_upgrade_data_from_csv:
                    try:
                        all_upgrade_data_from_csv[upgrade_id] = {
                            'max_purchase_level': int(row['Max Number of Levels']),
                            'money_cost': float(row['Base Money Cost']),
                            'money_cost_scaling_factor': float(row['Base Money Cost Scaling']),
                            'effects_to_apply': {} # Initialize effects dictionary
                        }
                    except ValueError as ve:
                        print(f"Warning: Data conversion error for basic properties of {upgrade_id} (CSV row {row_num}): {ve}. Skipping this upgrade entry.")
                        all_upgrade_data_from_csv.pop(upgrade_id, None) # Remove if partially added
                        continue
                    except KeyError as ke:
                        print(f"Warning: Missing basic property column for {upgrade_id} (CSV row {row_num}): {ke}. Skipping this upgrade entry.")
                        all_upgrade_data_from_csv.pop(upgrade_id, None) # Remove if partially added
                        continue
                
                # Add effect property from this row
                tres_prop_name = row.get('.tres property', '').strip()
                csv_effect_str = row.get('Effect per Level', '').strip()

                if tres_prop_name and csv_effect_str: # Ensure both are present
                    cleaned_value = clean_effect_value(csv_effect_str)
                    # Ensure 'effects_to_apply' exists, in case basic props failed for first row of this ID but not subsequent
                    if upgrade_id in all_upgrade_data_from_csv:
                         all_upgrade_data_from_csv[upgrade_id]['effects_to_apply'][tres_prop_name] = cleaned_value
                elif tres_prop_name and not csv_effect_str:
                    print(f"Warning: '.tres property' '{tres_prop_name}' found for {upgrade_id} (CSV row {row_num}) but 'Effect per Level' is missing.")
                elif not tres_prop_name and csv_effect_str:
                     print(f"Warning: 'Effect per Level' '{csv_effect_str}' found for {upgrade_id} (CSV row {row_num}) but '.tres property' is missing.")


            except Exception as e:
                print(f"Critical Error processing CSV row {row_num} for {row.get('UpgradeId', 'Unknown UpgradeId')}: {e}")

    # Now, iterate through the collected data and update .tres files
    successful_updates = 0
    no_changes_needed = 0
    file_not_found_errors = 0
    failed_reads_or_writes = 0
    files_processed_count = 0

    for upgrade_id, data in all_upgrade_data_from_csv.items():
        files_processed_count +=1
        tres_file_name = upgrade_id + ".tres"
        tres_file_path = os.path.join(GODOT_UPGRADES_PATH, tres_file_name)

        if not os.path.exists(tres_file_path):
            print(f"  Error: .tres file not found for {upgrade_id}: {tres_file_path}")
            file_not_found_errors += 1
            continue

        updates_for_tres = {
            'max_purchase_level': data['max_purchase_level'],
            'money_cost': data['money_cost'],
            'money_cost_scaling_factor': data['money_cost_scaling_factor']
        }
        updates_for_tres.update(data['effects_to_apply']) # Add all effect properties

        print(f"Processing {upgrade_id} ({os.path.basename(tres_file_path)})...")
        update_status = update_tres_file(tres_file_path, updates_for_tres)
        
        if update_status is True:
            successful_updates += 1
        elif update_status is False: 
            no_changes_needed +=1
        elif update_status is None: # Read or Write error
            failed_reads_or_writes +=1

    print("-" * 30)
    print("Update process finished.")
    print(f"Unique .tres files processed/attempted: {files_processed_count}")
    print(f"Successful file updates (changes written): {successful_updates}")
    print(f"Files with no changes needed: {no_changes_needed}")
    print(f".tres files not found: {file_not_found_errors}")
    print(f"File read/write errors: {failed_reads_or_writes}") # Renamed for clarity

if __name__ == '__main__':
    print("--- Godot .tres Updater Script ---")
    print(f"IMPORTANT: This script will attempt to modify .tres files in: {os.path.abspath(GODOT_UPGRADES_PATH)}")
    print(f"Reading data from CSV: {os.path.abspath(CSV_FILE_PATH)}")
    print("This script will SKIP THE FIRST LINE of the CSV file, assuming it's a title/meta line.")
    print("Assumes that if an UpgradeId appears on multiple rows, basic properties (Max Levels, Cost, Scaling) are the same on each row for that ID.")
    print("PLEASE BACK UP YOUR 'resources/upgrades' FOLDER BEFORE PROCEEDING.")
    
    confirm = input("Type 'yes' to continue: ")
    if confirm.lower() == 'yes':
        main()
    else:
        print("Operation cancelled by user.")