import csv
import os
import re

# --- CONFIGURATION ---
CSV_FILE_PATH = 'Balancing Sheet - Upgrade Definitions.csv' # Ensure this is your correct CSV file name
GODOT_UPGRADES_PATH = './resources/upgrades/'


# --- HELPER FUNCTIONS ---
def clean_effect_value(effect_str):
    effect_str = effect_str.strip()
    if effect_str.lower().startswith('x'): # Multiplier
        try:
            return float(effect_str[1:])
        except ValueError:
            return effect_str 
    elif effect_str.lower().startswith('unlocks '): # Unlock command
        recipe_name = effect_str[len('unlocks '):].strip()
        if not (recipe_name.startswith('"') and recipe_name.endswith('"')):
            recipe_name = f'"{recipe_name}"'
        return recipe_name
    else: # Try to parse as int, then float, then string
        try:
            return int(effect_str)
        except ValueError:
            try:
                return float(effect_str)
            except ValueError:
                return effect_str

def format_float_for_godot(f_val):
    if isinstance(f_val, int): 
        return f"{f_val}.0" 
    if isinstance(f_val, float):
        if f_val == int(f_val):
            return f"{int(f_val)}.0" 
        else:
            # Format to a reasonable number of decimal places, remove trailing zeros
            s = f"{f_val:.6g}".rstrip('0').rstrip('.')
            if not s or s == "-": 
                return "0.0"
            # If it became an integer string without 'e', ensure it has .0
            if '.' not in s and 'e' not in s.lower():
                 s = f"{float(s):.1f}" # Re-format to ensure at least one decimal place like .0
            return s
    return str(f_val) # Fallback for other types, though float is expected here


def update_tres_file(tres_file_path, updates):
    if not os.path.exists(tres_file_path):
        print(f"Warning: .tres file not found, cannot update: {tres_file_path}")
        return False # Indicate file not found

    lines = []
    updated_something = False
    try:
        with open(tres_file_path, 'r', encoding='utf-8') as f:
            lines = f.readlines()
    except Exception as e:
        print(f"Error reading {tres_file_path}: {e}") 
        return None # Indicate read error

    new_lines = []
    props_to_update_this_file = set(updates.keys()) # Keep track of props that need updating/adding
    
    for line_content in lines:
        current_line_for_prop_update = line_content
        matched_and_updated_this_line = False
        for prop_name, new_value in updates.items():
            # Regex to match property lines, e.g., "property_name = value"
            pattern = re.compile(rf"^\s*{re.escape(prop_name)}\s*=\s*(.*)")
            match = pattern.match(current_line_for_prop_update)

            if match:
                formatted_new_value_str = ""
                # Handle specific formatting for cost arrays
                if prop_name == "money_cost_per_level" or prop_name == "fusion_core_cost_per_level": 
                    if isinstance(new_value, list):
                        formatted_numbers = [format_float_for_godot(float(v)) for v in new_value] 
                        # Apply new Godot typed array format
                        formatted_new_value_str = f"Array[float]([{', '.join(formatted_numbers)}])"
                    else: # Should be an empty list if not a list of costs
                        formatted_new_value_str = "Array[float]([])" 
                # Handle other types
                elif isinstance(new_value, str): 
                    if new_value.startswith('"') and new_value.endswith('"'):
                        formatted_new_value_str = new_value
                    elif new_value.lower() in ['true', 'false']: # Handle boolean strings
                         formatted_new_value_str = new_value.lower()
                    else: # Default string formatting
                         formatted_new_value_str = f'"{new_value}"'
                elif isinstance(new_value, bool):
                    formatted_new_value_str = str(new_value).lower()
                elif isinstance(new_value, int): 
                    formatted_new_value_str = str(new_value)
                elif isinstance(new_value, float): 
                    formatted_new_value_str = format_float_for_godot(new_value)
                else: # Fallback for any other type
                    formatted_new_value_str = str(new_value) 

                # Construct the new line
                potential_new_line = f"{prop_name} = {formatted_new_value_str}\n"
                # Check if the new line is different from the old one
                if potential_new_line.strip() != current_line_for_prop_update.strip():
                    current_line_for_prop_update = potential_new_line
                    updated_something = True
                props_to_update_this_file.discard(prop_name) # Mark this prop as updated
                matched_and_updated_this_line = True
                break # Move to the next line in the file
        new_lines.append(current_line_for_prop_update)

    # Add any properties that were in the CSV but not found in the .tres file
    # These will be inserted before the first metadata line, or at the end if no metadata
    for prop_name in props_to_update_this_file: # Iterate over remaining props
        new_value = updates[prop_name]
        formatted_new_value_str = ""
        # Handle specific formatting for cost arrays (same as above)
        if prop_name == "money_cost_per_level" or prop_name == "fusion_core_cost_per_level":
             if isinstance(new_value, list):
                formatted_numbers = [format_float_for_godot(float(v)) for v in new_value]
                formatted_new_value_str = f"Array[float]([{', '.join(formatted_numbers)}])"
             else:
                formatted_new_value_str = "Array[float]([])"
        # Handle other types (same as above)
        elif isinstance(new_value, str):
             if new_value.startswith('"') and new_value.endswith('"'):
                formatted_new_value_str = new_value
             elif new_value.lower() in ['true', 'false']:
                formatted_new_value_str = new_value.lower()
             else:
                formatted_new_value_str = f'"{new_value}"'
        elif isinstance(new_value, bool):
            formatted_new_value_str = str(new_value).lower()
        elif isinstance(new_value, int):
             formatted_new_value_str = str(new_value)
        elif isinstance(new_value, float):
            formatted_new_value_str = format_float_for_godot(new_value)
        else:
            formatted_new_value_str = str(new_value)

        print(f"  Adding new property to .tres: {prop_name} = {formatted_new_value_str}") 
        inserted = False
        # Try to insert before metadata lines for better organization
        for i, line in enumerate(new_lines):
            if line.strip().startswith("metadata/_"): # Godot's metadata often starts with this
                new_lines.insert(i, f"{prop_name} = {formatted_new_value_str}\n")
                inserted = True
                break
        if not inserted: # If no metadata line found, append to the end
            new_lines.append(f"{prop_name} = {formatted_new_value_str}\n")
        updated_something = True

    # Write back to the file only if changes were made
    if updated_something:
        try:
            with open(tres_file_path, 'w', encoding='utf-8') as f:
                f.writelines(new_lines)
            return True # Indicate successful update
        except Exception as e:
            print(f"Error writing to {tres_file_path}: {e}") 
            return None # Indicate write error
    return False # Indicate no changes were made

# --- MAIN SCRIPT LOGIC ---
def main():
    if not os.path.exists(CSV_FILE_PATH):
        print(f"Error: CSV file not found at {CSV_FILE_PATH}")
        return

    if not os.path.isdir(GODOT_UPGRADES_PATH):
        print(f"Error: Godot upgrades directory not found at {GODOT_UPGRADES_PATH}")
        os.makedirs(GODOT_UPGRADES_PATH) # Create directory if it doesn't exist
        print(f"Created directory: {GODOT_UPGRADES_PATH}")
        # return # Original script returned here, but let's try to proceed if dir was created

    print("Starting .tres file update process...") 
    print("-" * 30)

    all_upgrade_data_from_csv = {}
    skipped_rows = 0
    failed_reads_or_writes = 0 

    with open(CSV_FILE_PATH, mode='r', encoding='utf-8-sig') as csvfile:
        try:
            # Skip the first line (assuming it's a title or notes, not headers)
            next(csvfile) 
        except StopIteration:
            print("Error: CSV file is empty or only had one line (title line).") 
            return

        reader = csv.DictReader(csvfile) # Second line is now treated as headers
        
        if not reader.fieldnames:
            print("Error: CSV file has no header row after skipping the first line.") 
            return

        # Define expected headers for validation
        expected_headers = ['UpgradeId', 'Max Number of Levels', 
                            '.tres property', 'Effect per Level', 
                            'Money Cost Array - Tweaked', 'Fusion Core Cost Array']
        missing_headers = [h for h in expected_headers if h not in reader.fieldnames]
        if missing_headers:
            print(f"Error: CSV file is missing expected headers: {', '.join(missing_headers)}") 
            print(f"Found headers: {', '.join(reader.fieldnames)}")
            return

        for row_num, row in enumerate(reader, 2): # Start row_num from 2 because we skipped one line
            try:
                upgrade_id = row.get('UpgradeId', '').strip()
                if not upgrade_id:
                    print(f"Warning: Skipping CSV row {row_num} due to missing 'UpgradeId'.")
                    skipped_rows +=1 
                    continue

                # Initialize data for this upgrade_id if it's the first time we see it
                if upgrade_id not in all_upgrade_data_from_csv:
                    try:
                        current_max_levels = int(row['Max Number of Levels'])
                        all_upgrade_data_from_csv[upgrade_id] = {
                            'max_purchase_level': current_max_levels,
                            'effects_to_apply': {} # Dictionary to store other properties
                        }
                        
                        # Process Money Cost Array
                        money_cost_array_str = row.get('Money Cost Array - Tweaked', '').strip()
                        if money_cost_array_str:
                            # Split by comma, strip whitespace, convert to float
                            money_cost_list = [float(c.strip()) for c in money_cost_array_str.split(',') if c.strip()]
                            if len(money_cost_list) != current_max_levels:
                                print(f"Warning: For {upgrade_id} (row {row_num}), 'Max Number of Levels' ({current_max_levels}) "
                                      f"does not match length of 'Money Cost Array - Tweaked' ({len(money_cost_list)}). Using provided array.")
                            all_upgrade_data_from_csv[upgrade_id]['money_cost_per_level'] = money_cost_list
                        else:
                            # If no money cost is specified, use an empty list or array of zeros
                            all_upgrade_data_from_csv[upgrade_id]['money_cost_per_level'] = [0.0] * current_max_levels
                            print(f"Info: For {upgrade_id} (row {row_num}), no 'Money Cost Array - Tweaked' provided. Defaulting to zeros.")
                        
                        # Process Fusion Core Cost Array
                        fusion_core_cost_array_str = row.get('Fusion Core Cost Array', '').strip()
                        if fusion_core_cost_array_str:
                            fusion_core_cost_list = [float(c.strip()) for c in fusion_core_cost_array_str.split(',') if c.strip()]
                            if len(fusion_core_cost_list) != current_max_levels:
                                print(f"Warning: For {upgrade_id} (row {row_num}), 'Max Number of Levels' ({current_max_levels}) "
                                      f"does not match length of 'Fusion Core Cost Array' ({len(fusion_core_cost_list)}). Using provided array.")
                            all_upgrade_data_from_csv[upgrade_id]['fusion_core_cost_per_level'] = fusion_core_cost_list
                        else:
                            # If no core cost is specified, assume an array of zeros
                            all_upgrade_data_from_csv[upgrade_id]['fusion_core_cost_per_level'] = [0.0] * current_max_levels
                            print(f"Info: For {upgrade_id} (row {row_num}), no 'Fusion Core Cost Array' provided. Defaulting to zeros.")

                    except ValueError as ve:
                        print(f"Warning: Data conversion error for base props of {upgrade_id} (CSV row {row_num}): {ve}. Skipping this UpgradeId.") 
                        all_upgrade_data_from_csv.pop(upgrade_id, None) # Remove partially processed data
                        skipped_rows +=1
                        continue
                    except KeyError as ke: 
                        print(f"Warning: Missing essential column for initial setup of {upgrade_id} (CSV row {row_num}): {ke}. Skipping this UpgradeId.") 
                        all_upgrade_data_from_csv.pop(upgrade_id, None)
                        skipped_rows +=1
                        continue
                
                # Process individual effects for this upgrade_id
                tres_prop_name = row.get('.tres property', '').strip()
                csv_effect_str = row.get('Effect per Level', '').strip()

                if tres_prop_name and csv_effect_str: # Only process if both are present
                    cleaned_value = clean_effect_value(csv_effect_str) 
                    if upgrade_id in all_upgrade_data_from_csv: # Ensure the base entry was created
                         all_upgrade_data_from_csv[upgrade_id]['effects_to_apply'][tres_prop_name] = cleaned_value
                elif tres_prop_name and not csv_effect_str:
                    print(f"Info: For {upgrade_id} (row {row_num}), '.tres property' '{tres_prop_name}' found but 'Effect per Level' is empty. Property will not be added/updated from this line.")
                
            except Exception as e: # Catch any other unexpected error for a row
                print(f"Critical Error processing CSV row {row_num} for {row.get('UpgradeId', 'Unknown UpgradeId')}: {e}. Skipping this row.") 
                failed_reads_or_writes +=1 # Count as a failure for this row

    # --- Process collected data and update .tres files ---
    successful_updates = 0
    no_changes_needed = 0
    file_not_found_errors = 0
    files_processed_count = 0

    for upgrade_id, data in all_upgrade_data_from_csv.items():
        files_processed_count +=1
        tres_file_name = upgrade_id + ".tres"
        tres_file_path = os.path.join(GODOT_UPGRADES_PATH, tres_file_name)

        # Prepare all updates for this .tres file
        updates_for_tres = {
            'max_purchase_level': data['max_purchase_level']
        }
        # Add cost arrays if they exist in the data
        if 'money_cost_per_level' in data: 
            updates_for_tres['money_cost_per_level'] = data['money_cost_per_level'] 
        if 'fusion_core_cost_per_level' in data: 
            updates_for_tres['fusion_core_cost_per_level'] = data['fusion_core_cost_per_level']

        # Add other effects
        updates_for_tres.update(data['effects_to_apply']) 

        # Attempt to update the file
        update_status = update_tres_file(tres_file_path, updates_for_tres)
        
        if update_status is True: # Changes were written
            successful_updates += 1
        elif update_status is False and os.path.exists(tres_file_path): # File existed, but no changes needed (or file not found handled by update_tres_file)
            no_changes_needed +=1
        elif update_status is False and not os.path.exists(tres_file_path): # File not found
             file_not_found_errors +=1
        elif update_status is None: # Read/write error during update_tres_file
            failed_reads_or_writes +=1

    # --- Print Summary ---
    print("-" * 30) 
    print("Update process finished.") 
    print(f"Unique UpgradeIds processed from CSV: {len(all_upgrade_data_from_csv)}")
    print(f".tres files processed/attempted: {files_processed_count}") 
    print(f"Successful file updates (changes written): {successful_updates}") 
    print(f"Files with no changes needed: {no_changes_needed}") 
    print(f".tres files not found (and not created): {file_not_found_errors}") 
    print(f"CSV rows skipped (due to errors or missing ID): {skipped_rows}") 
    print(f"File read/write or critical row processing errors: {failed_reads_or_writes}") 

if __name__ == '__main__':
    print("--- Godot .tres Updater Script (from CSV to .tres) ---") 
    print("This script updates .tres files in 'resources/upgrades/' based on a CSV.")
    print("Ensure your CSV has correct headers: UpgradeId, Max Number of Levels, .tres property, Effect per Level, Money Cost Array - Tweaked, Fusion Core Cost Array")
    print("PLEASE BACK UP YOUR 'resources/upgrades' FOLDER AND YOUR CSV BEFORE PROCEEDING.") 
    
    confirm = input("Type 'yes' to continue with the update: ")
    if confirm.lower() == 'yes':
        main()
    else:
        print("Operation cancelled by user.")
