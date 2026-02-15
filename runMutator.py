import os
import re
from pathlib import Path
import subprocess




class MembersSyntaxError(Exception):
    # txl openhab grammar does not reliably parse Group.members. syntax
    def __init__(self, message="'Group.members.' syntax unparseable"):
        super().__init__(message)

class RuleNumberError(Exception):
    # Mutators need at least 2 input rules
    def __init__(self, message="Input at least 2 valid/well-formatted openHAB rules."):
        super().__init__(message)

class EligibleAError(Exception):
    # Mutators need at least 2 input rules
    def __init__(self, message="No rules in ruleset eligible to be first rule. Check mutator conditions."):
        super().__init__(message)

class EligibleBError(Exception):
    # Mutators need at least 2 input rules
    def __init__(self, message="No rules in ruleset eligible to be second rule. Check mutator conditions."):
        super().__init__(message)

class EligibleABError(Exception):
    # Mutators need at least 2 input rules
    def __init__(self, message="Not enough eligible rules to perform mutation. Check mutator conditions."):
        super().__init__(message)





def get_rules(rules_filepath):
    # Open the .rules file in read mutation_mode
    with open(rules_filepath, 'r') as file:
        # Read the contents of the file
        file_contents = file.read()

    return separate_rules(file_contents)
    
def separate_rules(rules):
    # --- New: Remove single-line comments ---
    # Split the input string into lines
    lines = rules.splitlines()
    cleaned_lines = []
    for line in lines:
        # For each line, remove '//' and all subsequent characters
        cleaned_lines.append(re.sub(r'//.*', '', line))
    
    # Join the cleaned lines back into a single string
    # Using '\n' as a separator ensures consistent line endings for the regex engine
    rules_without_comments = "\n".join(cleaned_lines)
    # --- End of new comment removal section ---
    # 
    # 
    # # Initialize an empty list to store each rule
    rules_list = []
    imports_and_globals = []
    
    imports_and_globals_pattern = re.compile(r'^(.*?)rule "', re.DOTALL)

    rules_pattern = re.compile(r'(rule "(.*?)"(.*?\n.*?)' +
               r'when(.*?\n.*?)' +
               r'then(.*?\n.*?(?<!\S)\s*?)' +
               r'end\s*?(?!\S))'
               , re.DOTALL)
    
    imports_and_globals_match = re.findall(imports_and_globals_pattern, rules_without_comments)
    if imports_and_globals_match:
        imports_and_globals.append(imports_and_globals_match[0])

    rules_matches = re.findall(rules_pattern, rules_without_comments)
    if rules_matches:
        for rule_match in rules_matches:
            rules_list.append(rule_match[0])

    if len(rules_list) < 2:
        raise RuleNumberError
                
    return imports_and_globals, rules_list



def mutate_rules(original_rules_path, mutation_mode):
    '''
    # 1) Print Python’s idea of the current working directory
    python_cwd = os.getcwd()
    print(f"[Python] CWD: {python_cwd}")

    # 2) Print the subprocess’s cwd (on Windows, 'cd' is an internal shell command)
    proc = subprocess.run(
        'cd', 
        shell=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE
    )
    print(f"[subprocess] CWD: {proc.stdout.decode().strip()}")
    '''

    # Now run your txl mutator – and show the exact command and any errors
    txl_cmd = [
        'txl',
        original_rules_path,
        f'Txl_Mutators/{mutation_mode}.txl'
    ]
    print("→ Running:", txl_cmd)
    result = subprocess.run(
        txl_cmd,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE
    )

    if result.returncode != 0:
        print("!!! TXL failed:", result.stderr.decode())
        return ""

    return result.stdout.decode()

def post_process(mutated_rules):
    # Define the regex pattern for createTimer
    pattern = r'createTimer(.*?)\n(\s*)\[\|(.*?\n)'

    matches = re.findall(pattern, mutated_rules)

    for match in matches:
        print(match)

    # Define the replacement pattern for createTimer
    replacement = r'createTimer\1 [|\n\2\t\3'

    # Use re.sub() to find all matches and replace them
    modified_text = re.sub(pattern, replacement, mutated_rules)
    return modified_text

def main():
    
    input_folder       = r'Mutation_Output\\Rules_Files\\Original'
    output_folder      = 'Mutation_Output'
    mutation_mode_list = ['SAC']

    # 1) Iterate through every .rules file in input_folder
    for file_name in os.listdir(input_folder):
        if not file_name.endswith('.rules'):
            continue
        rules_file_name = os.path.splitext(file_name)[0]
        file_path       = os.path.join(input_folder, file_name)
        print(f'Processing: {rules_file_name}.rules')

        # Load and parse the rules file
        imports_and_globals, rules_list = get_rules(file_path)
        
        skip_list = []
        
        for i in range(len(rules_list)):
            if i in skip_list:
                continue
            for j in range(len(rules_list)):
                if i == j or j in skip_list:
                    continue

                # — write the “original” two-rule file for this pair —
                original_dir  = os.path.join(output_folder, 'Rules', 'Original')
                os.makedirs(original_dir, exist_ok=True)
                original_path = os.path.join(
                    original_dir,
                    f'{rules_file_name}_{i}_{j}.rules'
                )
                with open(original_path, 'w') as f:
                    f.write(rules_list[i] + '\n\n' + rules_list[j])

                for mutation_mode in mutation_mode_list: 
                    # Perform the mutation
                    mutate_rules(original_path, mutation_mode)

                    cwd = Path.cwd()
                    for path in cwd.glob(f"{mutation_mode}*.rules"):
                        fn           = path.name
                        integer      = fn[len(mutation_mode):-6]

                        integer = fn[len(mutation_mode):-6]   # strip off 'SAC' and '.rules'
                        curr_fp  = os.path.join(original_dir, fn)

                        # re-parse the mutated pair
                        _, mutated = get_rules(fn)
                        # post-process each side
                        mutated = [ post_process(r) for r in mutated ]

                        # write out just this mutated pair
                        mut_pair_dir = os.path.join(output_folder, 'Rules', 'Mutated', mutation_mode)
                        os.makedirs(mut_pair_dir, exist_ok=True)
                        mut_pair_fp = os.path.join(
                            mut_pair_dir,
                            f'{mutation_mode}_{rules_file_name}_{i}_{j}_{integer}.rules'
                        )
                        with open(mut_pair_fp, 'w') as f:
                            f.write(mutated[0] + '\n\n' + mutated[1])

                        # insert back into the full rules_list and write the full file
                        full_list = list(rules_list)  # copy
                        full_list[i], full_list[j] = mutated

                        full_mut_dir = os.path.join(output_folder, 'Rules_Files', 'Mutated', mutation_mode)
                        os.makedirs(full_mut_dir, exist_ok=True)
                        full_mut_fp = os.path.join(
                            full_mut_dir,
                            f'{mutation_mode}_{rules_file_name}_{i}_{j}_{integer}.rules'
                        )
                        with open(full_mut_fp, 'w') as f:
                            f.write(imports_and_globals[0])
                            f.write('\n\n')
                            for rule in full_list:
                                f.write(rule + '\n\n')

                        path.unlink()

                        

                
                
                '''
                # [IMPLEMENT: mutate_rules will produce many files in this directory
                # Each file name is of the pattern f'{mutation_mode}{integer}.rules'
                # Iterate through each file, and for each file perform the below logic]

                _, mutated_rules = get_rules(os.path.join(current_file))

                mutated_rules[0] = post_process(mutated_rules[0])
                mutated_rules[1] = post_process(mutated_rules[1])
                
                mutated_rules_path = f'{output_folder}/Rules/Mutated/{mutation_mode}_{i}_{j}_{integer}.rules'
                # Write the mutated rules to file
                with open(mutated_rules_path, 'w') as file:
                    file.write(mutated_rules[0] + '\n\n' + mutated_rules[1])

                # Replace the original rules in the file with the mutated rules
                rules_list[i], rules_list[j] = mutated_rules[0], mutated_rules[1]
                
                # Write the entire rules file with the mutation inserted to a file
                mutated_rules_file_path = f'{output_folder}/Rules_Files/Mutated/{mutation_mode}_{i}_{j}_{integer}.rules'
                with open(mutated_rules_file_path, 'w') as file:
                    file.write(imports_and_globals + '\n\n')
                    for rule in rules_list:
                        file.write(rule + '\n\n')
                        '''



if __name__ == '__main__':
    main()