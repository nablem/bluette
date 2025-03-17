import os
import re

def replace_with_opacity(directory):
    """
    Recursively searches for and replaces .withOpacity() with .withAlpha()
    in all Dart files within the given directory and its subdirectories.

    Args:
        directory: The starting directory to search.
    """

    for root, _, files in os.walk(directory):
        for filename in files:
            if filename.endswith(".dart"):
                filepath = os.path.join(root, filename)
                replace_in_file(filepath)


def replace_in_file(filepath):
    """
    Replaces .withOpacity() with .withAlpha() in a single Dart file.

    Args:
        filepath: The path to the Dart file.
    """

    try:
        with open(filepath, 'r', encoding='utf-8') as f:
            file_content = f.read()

        # Regular expression to find .withOpacity(some_number)
        # This regex handles:
        #   - Whitespace around the parentheses and the number.
        #   - Decimal numbers (e.g., 0.1, 1.0, .5)
        #   - Integer numbers (e.g. 1)
        #   - Cases where withOpacity might be part of a longer chain of calls.
        pattern = r'\.withOpacity\(\s*([0-9]*\.?[0-9]+|[0-9]+)\s*\)'

        def replacement(match):
            opacity_value_str = match.group(1)
            try:
                opacity_value = float(opacity_value_str)
                alpha_value = int(round(opacity_value * 255))
                return f".withAlpha({alpha_value})"
            except ValueError:
                 # if for some reason the value cannot be converted to float, return original string
                return match.group(0)
        
        new_content = re.sub(pattern, replacement, file_content)
        
        if new_content != file_content:  # Only write if changes were made
            with open(filepath, 'w', encoding='utf-8') as f:
                f.write(new_content)
            print(f"Updated: {filepath}")
        #else: #uncomment for debugging
            #print(f"No changes made to: {filepath}") # Optional: See which files had no matches

    except FileNotFoundError:
        print(f"Error: File not found: {filepath}")
    except Exception as e:
        print(f"Error processing {filepath}: {e}")


if __name__ == "__main__":
    current_directory = os.getcwd()  # Get the current working directory
    replace_with_opacity(current_directory)
    print("Replacement process complete.")