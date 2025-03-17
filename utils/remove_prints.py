import os
import re

def remove_print_statements(root_dir):
    """
    Removes all print() statements from Dart files within a directory and its subdirectories.

    Args:
        root_dir: The root directory to search for Dart files.
    """

    for dirpath, dirnames, filenames in os.walk(root_dir):
        for filename in filenames:
            if filename.endswith(".dart"):
                filepath = os.path.join(dirpath, filename)
                remove_print_from_file(filepath)


def remove_print_from_file(filepath):
    """Removes print() statements from a single Dart file."""

    try:
        with open(filepath, 'r', encoding='utf-8') as f:
            content = f.read()
    except UnicodeDecodeError:
        try:
            with open(filepath, 'r', encoding='latin-1') as f:  # Try latin-1 if utf-8 fails
                content = f.read()
        except Exception as e:
            print(f"Error reading file {filepath}: {e}")
            return
    except Exception as e:
        print(f"Error reading file {filepath}: {e}")
        return


    # Regex to match print statements, including multiline ones.
    #  - print\s*\( : Matches "print", followed by optional whitespace, then an opening parenthesis.
    #  - (?:.|\n)*? : Non-capturing group matching any character (including newline) zero or more times, non-greedy.
    #  - \);         : Matches a closing parenthesis followed by a semicolon.
    # The re.DOTALL flag makes the dot (.) match any character, *including* newlines.
    # The re.MULTILINE flag isn't strictly necessary here, as we're using . to match newlines, but can improve readability.
    
    pattern = r"print\s*\((?:.|\n)*?\);"
    new_content = re.sub(pattern, "", content, flags=re.DOTALL)

    if new_content != content:
        try:
            with open(filepath, 'w', encoding='utf-8') as f:
                f.write(new_content)
            print(f"Removed print statements from: {filepath}")
        except UnicodeEncodeError:
            try:
                with open(filepath, 'w', encoding='latin-1') as f:  # Try latin-1 if utf-8 fails
                    f.write(new_content)
                print(f"Removed print statements from: {filepath} (latin-1)")
            except Exception as e:
                 print(f"Error writing to file {filepath}: {e}")

        except Exception as e:
            print(f"Error writing to file {filepath}: {e}")


# Example usage (replace with your desired root directory):
if __name__ == "__main__":
    root_directory = "."  # Current directory.  Change this to your project's root.
    remove_print_statements(root_directory)
    print("Print statement removal complete.")