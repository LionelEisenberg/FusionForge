import csv
import os
import re

# --- CONFIGURATION ---
CSV_FILE_PATH = 'Balancing Sheet - Upgrade Definitions.csv' # Ensure this is your correct CSV file name
GODOT_UPGRADES_PATH = './resources/upgrades/'

# --- HELPER FUNCTIONS ---
def clean_effect_value(effect_str):
    """Cleans the effect string from CSV and attempts to convert to int, then float,
       or returns as a specially formatted string for unlocks."""
    effect_str = effect_str.strip()
    if effect_str.lower().startswith('x'): # Multiplier
        try:
            return float(effect_str[1:])
        except ValueError:
            print(f"Warning: Could not convert multiplier {effect_str} to float.")
            return effect_str # Return original on error
    elif effect_str.lower().startswith('unlocks '): # Unlock command
        recipe_name = effect_str[len('unlocks '):].strip()
        # Ensure the recipe name part is quoted for .tres file
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
                print(f"Warning: Could not parse '{effect_str}' as int or float, returning as string.")
                # If it's intended as a string value for .tres, it should ideally be quoted in CSV
                # or handled more specifically if it's a known non-numeric type (e.g. enum)
                return effect_str

def format_float_for_godot(f_val):
    """Formats a float for Godot .tres style (e.g., 10.0, 0.5, 123.456)."""
    if isinstance(f_val, int): # If it's already an int, format as float for array consistency if needed
        return f"{f_val}.0"
    if isinstance(f_val, float):
        if f_val == int(f_val):
            return f"{int(f_val)}.0" 
        else:
            s = f"{f_val:.6g}".rstrip('0').rstrip('.')
            if not s or s == "-": 
                return "0.0"
            if '.' not in s and 'e' not in s.lower():
                 s = f"{float(s):.1f}"
            return s
    return str(f_val) # Fallback for other types (should not happen for cost array)


def update_tres_file(tres_file_path, updates):
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
    props_to_update_this_file = set(updates.keys())
    
    for line_content in lines:
        current_line_for_prop_update = line_content
        # Iterate through a copy of updates if we might modify it, but here it's just for reading
        for prop_name, new_value in updates.items():
            pattern = re.compile(rf"^\s*{re.escape(prop_name)}\s*=\s*(.*)")
            match = pattern.match(current_line_for_prop_update)

            if match:
                formatted_new_value_str = ""
                if prop_name == "money_cost_per_level": # Corrected property name
                    if isinstance(new_value, list):
                        formatted_numbers = [format_float_for_godot(v) for v in new_value] # Values in cost array are floats
                        formatted_new_value_str = f"[{', '.join(formatted_numbers)}]"
                    else:
                        print(f"Warning: Expected a list for {prop_name} but got {type(new_value)}. Value: {new_value}")
                        formatted_new_value_str = "[]" 
                elif isinstance(new_value, str): # For effects like "unlocks" or pre-quoted strings
                    if new_value.startswith('"') and new_value.endswith('"'):
                        formatted_new_value_str = new_value
                    elif new_value.lower() in ['true', 'false']:
                         formatted_new_value_str = new_value.lower()
                    else: # Other strings from clean_effect_value that weren't unlocks
                         formatted_new_value_str = f'"{new_value}"'
                elif isinstance(new_value, bool):
                    formatted_new_value_str = str(new_value).lower()
                elif isinstance(new_value, int): # Handle integers directly
                    formatted_new_value_str = str(new_value)
                elif isinstance(new_value, float): # Handle floats directly
                    formatted_new_value_str = format_float_for_godot(new_value)
                else:
                    print(f"Warning: Unexpected type for new_value '{new_value}' for property '{prop_name}'.")
                    formatted_new_value_str = str(new_value) 

                potential_new_line = f"{prop_name} = {formatted_new_value_str}\n"
                if potential_new_line.strip() != current_line_for_prop_update.strip():
                    current_line_for_prop_update = potential_new_line
                    updated_something = True
                props_to_update_this_file.discard(prop_name)
                break 
        new_lines.append(current_line_for_prop_update)

    for prop_name in props_to_update_this_file:
        new_value = updates[prop_name]
        formatted_new_value_str = ""
        if prop_name == "money_cost_per_level": # Corrected property name
             if isinstance(new_value, list):
                formatted_numbers = [format_float_for_godot(v) for v in new_value]
                formatted_new_value_str = f"[{', '.join(formatted_numbers)}]"
             else:
                formatted_new_value_str = "[]"
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


        print(f"  Adding new property: {prop_name} = {formatted_new_value_str}")
        inserted = False
        for i, line in enumerate(new_lines):
            if line.strip().startswith("metadata/_"): 
                new_lines.insert(i, f"{prop_name} = {formatted_new_value_str}\n")
                inserted = True
                break
        if not inserted:
            new_lines.append(f"{prop_name} = {formatted_new_value_str}\n")
        updated_something = True


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

    all_upgrade_data_from_csv = {}

    with open(CSV_FILE_PATH, mode='r', encoding='utf-8-sig') as csvfile:
        try:
            next(csvfile)
            print("Skipped the first line of the CSV.")
        except StopIteration:
            print("Error: CSV file is empty or only had one line.")
            return

        reader = csv.DictReader(csvfile)
        
        if not reader.fieldnames:
            print("Error: CSV file has no header row after skipping the first line.")
            return

        expected_headers = ['UpgradeId', 'Max Number of Levels', 
                            '.tres property', 'Effect per Level', 'Money Cost Array - Tweaked']
        missing_headers = [h for h in expected_headers if h not in reader.fieldnames]
        if missing_headers:
            print(f"Error: CSV file is missing expected headers: {', '.join(missing_headers)}")
            print(f"  Detected headers: {reader.fieldnames}")
            return

        for row_num, row in enumerate(reader, 2):
            try:
                upgrade_id = row.get('UpgradeId', '').strip()
                if not upgrade_id:
                    print(f"Warning: Skipping CSV row {row_num} due to missing UpgradeId.")
                    continue

                if upgrade_id not in all_upgrade_data_from_csv:
                    try:
                        current_max_levels = int(row['Max Number of Levels'])
                        all_upgrade_data_from_csv[upgrade_id] = {
                            'max_purchase_level': current_max_levels, # This should be an int
                            'effects_to_apply': {}
                        }
                        cost_array_str = row.get('Money Cost Array - Tweaked', '').strip()
                        if cost_array_str:
                            # Costs in the array are floats
                            cost_list = [float(c.strip()) for c in cost_array_str.split(',')]
                            if len(cost_list) != current_max_levels:
                                print(f"Warning: For {upgrade_id}, 'Max Number of Levels' ({current_max_levels}) does not match the number of costs in 'Money Cost Array - Tweaked' ({len(cost_list)}). Using provided array as is.")
                            all_upgrade_data_from_csv[upgrade_id]['money_cost_per_level'] = cost_list # Corrected name
                        else:
                            print(f"Warning: Missing 'Money Cost Array - Tweaked' for {upgrade_id} (CSV row {row_num}). Cost array will be empty.")
                            all_upgrade_data_from_csv[upgrade_id]['money_cost_per_level'] = [] 

                    except ValueError as ve:
                        print(f"Warning: Data conversion error for properties of {upgrade_id} (CSV row {row_num}): {ve}. Skipping.")
                        all_upgrade_data_from_csv.pop(upgrade_id, None)
                        continue
                    except KeyError as ke: 
                        print(f"Warning: Missing essential column for {upgrade_id} (CSV row {row_num}): {ke}. Skipping.")
                        all_upgrade_data_from_csv.pop(upgrade_id, None)
                        continue
                
                tres_prop_name = row.get('.tres property', '').strip()
                csv_effect_str = row.get('Effect per Level', '').strip()

                if tres_prop_name and csv_effect_str:
                    cleaned_value = clean_effect_value(csv_effect_str) # clean_effect_value now tries int first
                    if upgrade_id in all_upgrade_data_from_csv:
                         all_upgrade_data_from_csv[upgrade_id]['effects_to_apply'][tres_prop_name] = cleaned_value
                elif tres_prop_name and not csv_effect_str:
                    print(f"Warning: '.tres property' '{tres_prop_name}' found for {upgrade_id} (CSV row {row_num}) but 'Effect per Level' is missing.")
                # No warning if both are empty, could be a row just for basic props if CSV is structured that way.

            except Exception as e:
                print(f"Critical Error processing CSV row {row_num} for {row.get('UpgradeId', 'Unknown UpgradeId')}: {e}")

    # Update .tres files
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
            'max_purchase_level': data['max_purchase_level'] # This is an int
        }
        if 'money_cost_per_level' in data: # Corrected name
            updates_for_tres['money_cost_per_level'] = data['money_cost_per_level'] # This is a list of floats

        updates_for_tres.update(data['effects_to_apply']) # Effects can be int, float, or string

        print(f"Processing {upgrade_id} ({os.path.basename(tres_file_path)})...")
        update_status = update_tres_file(tres_file_path, updates_for_tres)
        
        if update_status is True:
            successful_updates += 1
        elif update_status is False: 
            no_changes_needed +=1
        elif update_status is None:
            failed_reads_or_writes +=1

    print("-" * 30)
    print("Update process finished.")
    print(f"Unique .tres files processed/attempted: {files_processed_count}")
    print(f"Successful file updates (changes written): {successful_updates}")
    print(f"Files with no changes needed: {no_changes_needed}")
    print(f".tres files not found: {file_not_found_errors}")
    print(f"File read/write errors: {failed_reads_or_writes}")

if __name__ == '__main__':
    print("--- Godot .tres Updater Script (Array Costs) ---")
    print(f"IMPORTANT: This script will attempt to modify .tres files in: {os.path.abspath(GODOT_UPGRADES_PATH)}")
    print(f"Reading data from CSV: {os.path.abspath(CSV_FILE_PATH)}")
    print("This script will SKIP THE FIRST LINE of the CSV file.")
    print("It will read 'Money Cost Array - Tweaked' and write to 'money_cost_per_level' in .tres.") # Corrected name
    print("PLEASE BACK UP YOUR 'resources/upgrades' FOLDER AND UPDATE UpgradeData.gd BEFORE PROCEEDING.")
    
    confirm = input("Type 'yes' to continue: ")
    if confirm.lower() == 'yes':
        main()
    else:
        print("Operation cancelled by user.")