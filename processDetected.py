import os
import re
from pathlib import Path
import pandas as pd

def extract_values(file_text):
    """
    Extracts values for the keys 'SAC', 'WAC', 'STC', 'WTC', 'SCC', 'WCC'
    from the provided text, converting them to binary (0 or 1). 
    Any value greater than or equal to 1 is stored as 1.
    Returns a dict mapping each key to its binary integer value.
    """
    expected_keys = ['SAC', 'WAC', 'STC', 'WTC', 'SCC', 'WCC']
    values = {}
    
    for key in expected_keys:
        pattern = rf'{key}:\s*(\d)'
        match = re.search(pattern, file_text)
        if match:
            num = int(match.group(1))
            values[key] = 1 if num >= 1 else 0
        else:
            values[key] = 0
    return values

def process_files():
    # Set the root directory
    root_dir = Path(r'Mutation_Detected\\Rules\\Mutated')
    
    # Prepare a list to collect each file's data
    data_rows = []
    
    # Iterate through each file in the directory structure recursively.
    for file_path in root_dir.rglob('*.txt'):
        if file_path.is_file():
            filepath_str = str(file_path)
            try:
                with open(file_path, 'r', encoding='utf-8') as f:
                    file_text = f.read()
            except Exception as e:
                print(f"Could not read file {filepath_str}: {e}")
                continue
            
            # Extract the 6 binary values from the text file.
            values = extract_values(file_text)
            
            # Extract the three-letter acronym from the file name.
            # It is assumed to be the first part of the filename split by '-'
            acronym = file_path.stem.split("_")[0]
            
            # Determine the Correct column:
            # If the binary value (already 0 or 1) for the acronym is 1, then it's correct.
            correct_val = 1 if values.get(acronym, 0) == 1 else 0
            
            # Build the row: filepath, SAC, WAC, STC, WTC, SCC, WCC, Correct
            row = [
                filepath_str,
                values['SAC'],
                values['WAC'],
                values['STC'],
                values['WTC'],
                values['SCC'],
                values['WCC'],
                correct_val
            ]
            
            data_rows.append(row)
    
    # Create the DataFrame.
    columns = ['filepath', 'SAC', 'WAC', 'STC', 'WTC', 'SCC', 'WCC', 'Correct']
    df = pd.DataFrame(data_rows, columns=columns)
    
    # Save the DataFrame as a CSV.
    df.to_csv('Mutation_Detected.csv', index=False)
    print("DataFrame saved to 'Mutation_Detected.csv'.")



def analyze_dataframe(df):
    """
    Performs several analyses on the dataframe.

    1. Counts how many files (based on their file name) are associated with each main RIT.
    2. For each main RIT, determines the number of correct/incorrect entries and calculates the percent correct.
    3. Counts how many files have more than one RIT (i.e., more than one column among SAC, WAC, STC, WTC, SCC, WCC equals 1).
    4. Sums the occurrences (1's) for each RIT column across the entire dataframe.
    """
    # Extract the main RIT from the file name (assumed to be the first part of the file name split by '-')
    df['main_RIT'] = df['filepath'].apply(
    lambda x: re.split(r'[-_]', os.path.basename(x), maxsplit=1)[0]
)
    
    # 1. Count main RIT occurrences based on the file name.
    print("Main RIT Occurrence Counts in file names:")
    main_counts = df['main_RIT'].value_counts()
    for rit, count in main_counts.items():
        print(f"  {rit}: {count}")
    print("\n")
    
    # 2. Count correct vs incorrect for each main RIT.
    print("Correct vs Incorrect counts for each main RIT:")
    print(f"{'RIT':<5} {'Correct':<8} {'Incorrect':<10} {'Percent'}")
    grouped = df.groupby('main_RIT')
    for rit, group in grouped:
        total = group.shape[0]
        correct = group['Correct'].sum()  # Because Correct is binary 1 for correct, 0 for incorrect.
        incorrect = total - correct
        percent = (correct / total * 100) if total > 0 else 0
        print(f"{rit:<5} {correct:<8} {incorrect:<10} {percent:.2f}%")
    print("\n")
    
    # 3. Count how many files have more than one RIT present.
    # Compute the number of RITs present in each file by summing the binary values from the 6 RIT columns.
    rits = ['SAC', 'WAC', 'STC', 'WTC', 'SCC', 'WCC']
    df['rit_count'] = df[rits].sum(axis=1)
    multi_rit_files = df[df['rit_count'] > 1].shape[0]
    total_files = df.shape[0]
    print(f"Files with more than one RIT (total files: {total_files}): {multi_rit_files}")
    print("\n")
    
    # 4. Count total occurrences for each RIT across all files.
    print("Total occurrences for each RIT (summing the 1's in each column):")
    for col in rits:
        print(f"  {col}: {int(df[col].sum())}")
    
    # Optionally, remove the temporary columns added for analysis.
    df.drop(columns=['main_RIT', 'rit_count'], inplace=True)



if __name__ == '__main__':
    print("Current working directory:", os.getcwd())
    os.chdir(os.path.dirname(os.path.abspath(__file__)))
    print("Current working directory:", os.getcwd())
    
    
    process_files()

    # Load the dataframe from the CSV we created previously.
    df = pd.read_csv('Mutation_Detected.csv')

    analyze_dataframe(df)



'''
Main RIT Occurrence Counts in file names:
  STC: 370
  WTC: 370
  SAC: 47
  WAC: 44
  SCC: 11
  WCC: 10


Correct vs Incorrect counts for each main RIT:
RIT   Correct  Incorrect  Percent
SAC   47       0          100.00%
SCC   8        3          72.73%
STC   245      125        66.22%
WAC   21       23         47.73%
WCC   4        6          40.00%
WTC   112      258        30.27%


Files with more than one RIT (total files: 852): 293


Total occurrences for each RIT (summing the 1's in each column):
  SAC: 190
  WAC: 150
  STC: 452
  WTC: 190
  SCC: 31
  WCC: 15

'''