import os
import sys

def remove_duplicate_lines(directory, target_line):
    for root, dirs, files in os.walk(directory):
        if '.git' in dirs:
            config_path = os.path.join(root, '.git', 'config')
            if os.path.isfile(config_path):
                with open(config_path, 'r') as file:
                    lines = file.readlines()
                
                # Remove duplicate lines
                seen = set()
                new_lines = []
                for line in lines:
                    if line.strip() == target_line:
                        if line.strip() in seen:
                            continue
                        seen.add(line.strip())
                    new_lines.append(line)
                
                # Write back to the file
                with open(config_path, 'w') as file:
                    file.writelines(new_lines)

if __name__ == "__main__":
    if len(sys.argv) != 2:
        print("Usage: python script.py <directory>")
        sys.exit(1)
    
    directory = sys.argv[1]
    target_line = "vscode-merge-base = origin/main"
    remove_duplicate_lines(directory, target_line)