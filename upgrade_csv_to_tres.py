import csv
import os
import re

# --- CONFIGURATION ---
# Path to your "Upgrade Definitions" CSV file
CSV_FILE_PATH = 'Balancing Sheet - Upgrade Definitions.csv'  # Or full path like '/path/to/your/Balancing Sheet - Sheet1.csv'

# Path to your Godot project's upgrades directory
GODOT_UPGRADES_PATH = './resources/upgrades/' # Assumes script is run from parent of FusionForge, or adjust as needed

# --- HELPER FUNCTIONS ---

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
        # Ensure the recipe name part is quoted for .tres file
        recipe_name = effect_str[len('unlocks '):].strip()
        if not (recipe_name.startswith('"') and recipe_name.endswith('"')):
            recipe_name = f'"{recipe_name}"'
        return recipe_name # Return the quoted recipe name directly
    else:
        try:
            return float(effect_str)
        except ValueError:
            print(f"Warning: Could not parse '{effect_str}' as float, returning as string.")
            # If it's intended as a string value for .tres, it should ideally be quoted in CSV
            # or handled more specifically if it's a known non-numeric type (e.g. enum)
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
        return False

    new_lines = []
    for line in lines:
        original_line = line # Keep original for comparison if no update on this line
        for prop_name, new_value in updates.items():
            # Regex to match 'property_name = value'
            pattern = re.compile(rf"^\s*{re.escape(prop_name)}\s*=\s*(.*)")
            match = pattern.match(line)
            if match:
                current_value_str = match.group(1).strip()
                formatted_new_value = ""

                # Format the new value correctly for .tres
                if isinstance(new_value, str):
                    # If clean_effect_value already quoted it (like for unlocks)
                    if new_value.startswith('"') and new_value.endswith('"'):
                        formatted_new_value = new_value
                    # Handle booleans passed as strings
                    elif new_value.lower() in ['true', 'false']:
                         formatted_new_value = new_value.lower()
                    # Otherwise, assume it's a string that needs quotes
                    else:
                         formatted_new_value = f'"{new_value}"'
                elif isinstance(new_value, bool):
                    formatted_new_value = str(new_value).lower()
                elif isinstance(new_value, (int, float)):
                    if isinstance(new_value, float) and new_value == int(new_value):
                        formatted_new_value = str(int(new_value))
                    elif isinstance(new_value, float):
                        formatted_new_value = f"{new_value:.4g}".rstrip('0').rstrip('.')
                        if not formatted_new_value or formatted_new_value == "-": # Handle cases like 0.0 becoming ""
                            formatted_new_value = "0"
                        elif '.' not in formatted_new_value and 'e' not in formatted_new_value.lower(): # if it became an int string
                             formatted_new_value = f"{float(formatted_new_value):.1f}" # ensure it has .0 for Godot
                    else: # int
                        formatted_new_value = str(new_value)
                else:
                    print(f"Warning: Unexpected type for new_value '{new_value}' for property '{prop_name}'. Skipping update for this property.")
                    formatted_new_value = current_value_str # fallback to current value string

                # Only update if the new formatted value is different from the current one
                # This avoids unnecessary file writes and "updated" messages for no actual change.
                # Need to be careful comparing string representations of numbers vs actual numbers.
                # For simplicity here, we'll compare the string that would be written.
                potential_new_line = f"{prop_name} = {formatted_new_value}\n"
                if potential_new_line.strip() != line.strip():
                    line = potential_new_line
                    updated_something = True
                break # Processed this property for this line
        new_lines.append(line)

    if updated_something:
        try:
            with open(tres_file_path, 'w', encoding='utf-8') as f:
                f.writelines(new_lines)
            return True
        except Exception as e:
            print(f"Error writing to {tres_file_path}: {e}")
            return False
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

    successful_updates = 0
    no_changes_needed = 0
    failed_updates = 0
    files_processed_count = 0 # Count of unique files attempted to process

    processed_files_this_run = set()

    with open(CSV_FILE_PATH, mode='r', encoding='utf-8-sig') as csvfile:
        try:
            next(csvfile)  # Consume and discard the first line
            print("Skipped the first line of the CSV.")
        except StopIteration:
            print("Error: CSV file is empty (could not skip first line).")
            return

        reader = csv.DictReader(csvfile)
        if not reader.fieldnames:
            print("Error: CSV file appears to be empty or has no header.")
            return

        expected_headers = ['UpgradeId', 'Max Number of Levels', 'Base Money Cost',
                            'Base Money Cost Scaling', '.tres property', 'Effect per Level']
        missing_headers = [h for h in expected_headers if h not in reader.fieldnames]
        if missing_headers:
            print(f"Error: CSV file is missing expected headers: {', '.join(missing_headers)}")
            print(f"Please ensure your CSV has at least these columns: {', '.join(expected_headers)}")
            return

        for row_num, row in enumerate(reader, 1):
            try:
                upgrade_id = row.get('UpgradeId', '').strip()
                if not upgrade_id:
                    print(f"Warning: Skipping row {row_num} due to missing UpgradeId.")
                    failed_updates +=1 # Consider this a failure to process the row
                    continue

                tres_file_name = upgrade_id + ".tres"
                tres_file_path = os.path.join(GODOT_UPGRADES_PATH, tres_file_name)

                if tres_file_path not in processed_files_this_run:
                    files_processed_count +=1
                    processed_files_this_run.add(tres_file_path)


                updates_for_tres = {}

                # Basic properties
                try:
                    updates_for_tres['max_purchase_level'] = int(row['Max Number of Levels'])
                    updates_for_tres['money_cost'] = float(row['Base Money Cost'])
                    updates_for_tres['money_cost_scaling_factor'] = float(row['Base Money Cost Scaling'])
                except ValueError as ve:
                    print(f"Warning: Skipping basic property update for {upgrade_id} due to data conversion error in row {row_num}: {ve}. Check CSV values.")
                except KeyError as ke:
                    print(f"Warning: Skipping basic property update for {upgrade_id} due to missing column in row {row_num}: {ke}")

                # Effect properties
                csv_tres_properties_combined = row.get('.tres property', '').strip()
                csv_effect_per_level_combined = row.get('Effect per Level', '').strip()

                tres_properties_list = [p.strip() for p in csv_tres_properties_combined.split('&')]
                effects_list = [e.strip() for e in csv_effect_per_level_combined.split('&')]

                if len(tres_properties_list) != len(effects_list) and csv_tres_properties_combined:
                    print(f"Warning: Mismatch between number of .tres properties and effects for {upgrade_id} in row {row_num}.")
                    print(f"  Properties: '{csv_tres_properties_combined}', Effects: '{csv_effect_per_level_combined}'")
                    print(f"  Attempting to process based on the shorter list or skipping effect for this row.")
                    # Adjust lists to the minimum common length to avoid errors, or skip
                    min_len = min(len(tres_properties_list), len(effects_list))
                    tres_properties_list = tres_properties_list[:min_len]
                    effects_list = effects_list[:min_len]
                    if not min_len: # If one list was empty and the other wasn't
                        print(f"  Skipping effect update for {upgrade_id} due to mismatch.")


                for i, tres_prop_name in enumerate(tres_properties_list):
                    if tres_prop_name and i < len(effects_list): # Ensure effect exists for this property
                        csv_effect_str = effects_list[i]
                        cleaned_value = clean_effect_value(csv_effect_str)
                        updates_for_tres[tres_prop_name] = cleaned_value
                    elif tres_prop_name: # Property listed but no corresponding effect
                        print(f"Warning: No corresponding effect found for .tres property '{tres_prop_name}' for {upgrade_id} in row {row_num}.")


                if updates_for_tres:
                    print(f"Processing {upgrade_id} ({os.path.basename(tres_file_path)})...")
                    if not os.path.exists(tres_file_path):
                         print(f"  Error: .tres file not found: {tres_file_path}")
                         failed_updates += 1
                         continue # Skip to next row if file doesn't exist

                    update_status = update_tres_file(tres_file_path, updates_for_tres)
                    if update_status is True: # Explicitly True means changes were made and saved
                        successful_updates += 1
                    elif update_status is False and os.path.exists(tres_file_path): # False means no changes needed or error writing
                        # If it exists but update_tres_file returned False, it could be "no changes" or an error.
                        # The function update_tres_file prints errors. Here we assume if it's False, no changes were made.
                        no_changes_needed +=1
                    elif update_status is False and not os.path.exists(tres_file_path): # File not found was handled inside
                        failed_updates +=1


                else:
                    print(f"No valid updates to apply for {upgrade_id} from row {row_num} (e.g. missing data or only header).")
                    # This might not be a failure if the row was intentionally sparse or just a header
                    # Consider if this should increment failed_updates or a new "skipped_rows" counter

            except Exception as e:
                print(f"Critical Error processing row {row_num} for {row.get('UpgradeId', 'Unknown UpgradeId')}: {e}")
                failed_updates += 1

    print("-" * 30)
    print("Update process finished.")
    print(f"Unique .tres files processed/attempted: {files_processed_count}")
    print(f"Successful file updates (changes written): {successful_updates}")
    print(f"Files with no changes needed: {no_changes_needed}")
    print(f"Failed/Skipped row processing or file errors: {failed_updates}")

if __name__ == '__main__':
    print("--- Godot .tres Updater Script ---")
    print(f"IMPORTANT: This script will attempt to modify .tres files in: {os.path.abspath(GODOT_UPGRADES_PATH)}")
    print(f"Reading data from CSV: {os.path.abspath(CSV_FILE_PATH)}")
    print("PLEASE BACK UP YOUR 'resources/upgrades' FOLDER BEFORE PROCEEDING.")
    
    confirm = input("Type 'yes' to continue: ")
    if confirm.lower() == 'yes':
        main()
    else:
        print("Operation cancelled by user.")