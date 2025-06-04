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
            s = f"{f_val:.6g}".rstrip('0').rstrip('.')
            if not s or s == "-": 
                return "0.0"
            if '.' not in s and 'e' not in s.lower():
                 s = f"{float(s):.1f}"
            return s
    return str(f_val)


def update_tres_file(tres_file_path, updates):
    if not os.path.exists(tres_file_path):
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
        matched_and_updated_this_line = False
        for prop_name, new_value in updates.items():
            pattern = re.compile(rf"^\s*{re.escape(prop_name)}\s*=\s*(.*)")
            match = pattern.match(current_line_for_prop_update)

            if match:
                formatted_new_value_str = ""
                if prop_name == "money_cost_per_level" or prop_name == "fusion_core_cost_per_level": 
                    if isinstance(new_value, list):
                        # For cost arrays, all elements should be formatted as floats for Godot
                        formatted_numbers = [format_float_for_godot(float(v)) for v in new_value] 
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

                potential_new_line = f"{prop_name} = {formatted_new_value_str}\n"
                if potential_new_line.strip() != current_line_for_prop_update.strip():
                    current_line_for_prop_update = potential_new_line
                    updated_something = True
                props_to_update_this_file.discard(prop_name)
                matched_and_updated_this_line = True
                break 
        new_lines.append(current_line_for_prop_update)

    for prop_name in props_to_update_this_file:
        new_value = updates[prop_name]
        formatted_new_value_str = ""
        if prop_name == "money_cost_per_level" or prop_name == "fusion_core_cost_per_level":
             if isinstance(new_value, list):
                formatted_numbers = [format_float_for_godot(float(v)) for v in new_value]
                formatted_new_value_str = f"Array[float]([{', '.join(formatted_numbers)}])"
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
    print("-" * 30)

    all_upgrade_data_from_csv = {}
    skipped_rows = 0
    failed_reads_or_writes = 0 # Added this counter

    with open(CSV_FILE_PATH, mode='r', encoding='utf-8-sig') as csvfile:
        try:
            next(csvfile)
        except StopIteration:
            print("Error: CSV file is empty or only had one line.") 
            return

        reader = csv.DictReader(csvfile)
        
        if not reader.fieldnames:
            print("Error: CSV file has no header row after skipping the first line.") 
            return

        expected_headers = ['UpgradeId', 'Max Number of Levels', 
                            '.tres property', 'Effect per Level', 
                            'Money Cost Array - Tweaked', 'Fusion Core Cost Array'] # Added Fusion Core Cost Array
        missing_headers = [h for h in expected_headers if h not in reader.fieldnames]
        if missing_headers:
            print(f"Error: CSV file is missing expected headers: {', '.join(missing_headers)}") 
            return

        for row_num, row in enumerate(reader, 2): 
            try:
                upgrade_id = row.get('UpgradeId', '').strip()
                if not upgrade_id:
                    skipped_rows +=1 
                    continue

                if upgrade_id not in all_upgrade_data_from_csv:
                    try:
                        current_max_levels = int(row['Max Number of Levels'])
                        all_upgrade_data_from_csv[upgrade_id] = {
                            'max_purchase_level': current_max_levels,
                            'effects_to_apply': {}
                        }
                        
                        money_cost_array_str = row.get('Money Cost Array - Tweaked', '').strip()
                        if money_cost_array_str:
                            money_cost_list = [float(c.strip()) for c in money_cost_array_str.split(',')]
                            if len(money_cost_list) != current_max_levels:
                                print(f"Warning: For {upgrade_id}, 'Max Number of Levels' ({current_max_levels}) does not match length of 'Money Cost Array - Tweaked' ({len(money_cost_list)}).")
                            all_upgrade_data_from_csv[upgrade_id]['money_cost_per_level'] = money_cost_list
                        else:
                            all_upgrade_data_from_csv[upgrade_id]['money_cost_per_level'] = [] 
                        
                        # --- NEW: Read Fusion Core Cost Array ---
                        fusion_core_cost_array_str = row.get('Fusion Core Cost Array', '').strip()
                        if fusion_core_cost_array_str:
                            fusion_core_cost_list = [float(c.strip()) for c in fusion_core_cost_array_str.split(',')] # Assuming cores can be floats for consistency, convert to int in GDScript if needed
                            if len(fusion_core_cost_list) != current_max_levels:
                                print(f"Warning: For {upgrade_id}, 'Max Number of Levels' ({current_max_levels}) does not match length of 'Fusion Core Cost Array' ({len(fusion_core_cost_list)}).")
                            all_upgrade_data_from_csv[upgrade_id]['fusion_core_cost_per_level'] = fusion_core_cost_list
                        else:
                            # If no core cost is specified, assume an array of zeros matching max_purchase_level
                            all_upgrade_data_from_csv[upgrade_id]['fusion_core_cost_per_level'] = [0.0] * current_max_levels


                    except ValueError as ve:
                        print(f"Warning: Data conversion error for props of {upgrade_id} (CSV row {row_num}): {ve}.") 
                        all_upgrade_data_from_csv.pop(upgrade_id, None)
                        skipped_rows +=1
                        continue
                    except KeyError as ke: 
                        print(f"Warning: Missing essential column for {upgrade_id} (CSV row {row_num}): {ke}.") 
                        all_upgrade_data_from_csv.pop(upgrade_id, None)
                        skipped_rows +=1
                        continue
                
                tres_prop_name = row.get('.tres property', '').strip()
                csv_effect_str = row.get('Effect per Level', '').strip()

                if tres_prop_name and csv_effect_str:
                    cleaned_value = clean_effect_value(csv_effect_str) 
                    if upgrade_id in all_upgrade_data_from_csv:
                         all_upgrade_data_from_csv[upgrade_id]['effects_to_apply'][tres_prop_name] = cleaned_value
                
            except Exception as e:
                print(f"Critical Error processing CSV row {row_num} for {row.get('UpgradeId', 'Unknown UpgradeId')}: {e}") 
                failed_reads_or_writes +=1 

    successful_updates = 0
    no_changes_needed = 0
    file_not_found_errors = 0
    files_processed_count = 0

    for upgrade_id, data in all_upgrade_data_from_csv.items():
        files_processed_count +=1
        tres_file_name = upgrade_id + ".tres"
        tres_file_path = os.path.join(GODOT_UPGRADES_PATH, tres_file_name)

        if not os.path.exists(tres_file_path):
            file_not_found_errors += 1
            continue

        updates_for_tres = {
            'max_purchase_level': data['max_purchase_level']
        }
        if 'money_cost_per_level' in data: 
            updates_for_tres['money_cost_per_level'] = data['money_cost_per_level'] 
        if 'fusion_core_cost_per_level' in data: # Add fusion core costs
            updates_for_tres['fusion_core_cost_per_level'] = data['fusion_core_cost_per_level']

        updates_for_tres.update(data['effects_to_apply']) 

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
    print(f"CSV rows skipped (due to errors or missing ID): {skipped_rows}") 
    print(f"File read/write or critical row processing errors: {failed_reads_or_writes}") 

if __name__ == '__main__':
    print("--- Godot .tres Updater Script (Array Costs for Money & Fusion Cores) ---") 
    print("PLEASE BACK UP YOUR 'resources/upgrades' FOLDER AND UPDATE UpgradeData.gd BEFORE PROCEEDING.") 
    
    confirm = input("Type 'yes' to continue: ")
    if confirm.lower() == 'yes':
        main()
    else:
        print("Operation cancelled by user.") 