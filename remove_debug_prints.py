import re
import os
from pathlib import Path

def remove_debug_prints(file_path: str) -> tuple[bool, str]:
    """
    Remove debug print statements from a file while preserving proper logging.
    Returns (was_modified: bool, new_content: str)
    """
    with open(file_path, 'r', encoding='utf-8') as f:
        content = f.read()
    
    # Patterns to match debug prints
    patterns = [
        # Python debug prints
        r'print\s*\(["\']🔄.*?[\'"]\).*?\n',  # Emoji debug prints
        r'print\s*\(["\']✅.*?[\'"]\).*?\n',
        r'print\s*\(["\']❌.*?[\'"]\).*?\n',
        r'print\s*\(["\']🔑.*?[\'"]\).*?\n',
        r'print\s*\(["\']<THOR DEBUG>.*?[\'"]\).*?\n',  # Thor debug prints
        r'print\s*\(f["\']<THOR DEBUG>.*?[\'"]\).*?\n',
        r'print\s*\(["\']Debug:.*?[\'"]\).*?\n',  # Generic debug prints
        r'print\s*\(f["\']Debug:.*?[\'"]\).*?\n',
        r'print\(response\)\n',  # Simple print statements
        
        # Swift debug prints
        r'print\("🔄.*?"\)\n',  # Swift emoji prints
        r'print\("✅.*?"\)\n',
        r'print\("❌.*?"\)\n',
        r'print\("🔑.*?"\)\n',
        r'print\("Debug:.*?"\)\n',
        
        # Swift string interpolation prints
        r'print\(".*?\(.*?\).*?"\)\n',  # Matches print("... \(variable) ...")
        
        # General cleanup
        r'print\("={20,}"\)\n',  # Remove separator prints
        r'print\(".*?"\)\n',  # Generic string prints
        
        # Multi-line prints
        r'print\(\n\s*"""[\s\S]*?"""\n\s*\)\n',  # Python multi-line
        r'print\("""[\s\S]*?"""\)\n',  # Python single-line multi-line
    ]
    
    original = content
    for pattern in patterns:
        content = re.sub(pattern, '', content)
    
    # Clean up any double newlines created by removing prints
    content = re.sub(r'\n\s*\n\s*\n', '\n\n', content)
    
    was_modified = original != content
    return was_modified, content

def process_directory(directory: str) -> list[str]:
    """
    Process all Python and Swift files in the directory and its subdirectories.
    Returns list of modified files.
    """
    modified_files = []
    
    for root, _, files in os.walk(directory):
        for file in files:
            if file.endswith(('.py', '.swift')):
                file_path = os.path.join(root, file)
                try:
                    was_modified, new_content = remove_debug_prints(file_path)
                    
                    if was_modified:
                        print(f"Modifying {file_path}")
                        with open(file_path, 'w', encoding='utf-8') as f:
                            f.write(new_content)
                        modified_files.append(file_path)
                except Exception as e:
                    print(f"Error processing {file_path}: {str(e)}")
    
    return modified_files

# Main execution
if __name__ == "__main__":
    base_dir = "thorgodoflightning"  # Update this to your project root
    modified = process_directory(base_dir)
    
    print("\nModified files:")
    for file in modified:
        print(f"- {file}")