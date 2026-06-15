import os

def search_files(directory, queries):
    for query in queries:
        print(f"\n=== Searching for '{query}' ===")
        matches = []
        for root, dirs, files in os.walk(directory):
            if '.git' in root or '.dart_tool' in root or 'build' in root:
                continue
            for file in files:
                if file.endswith('.dart'):
                    filepath = os.path.join(root, file)
                    try:
                        with open(filepath, 'r', encoding='utf-8') as f:
                            for line_num, line in enumerate(f, 1):
                                if query.lower() in line.lower():
                                    matches.append((filepath, line_num, line.strip()))
                    except Exception as e:
                        pass
        print(f"Found {len(matches)} matches:")
        for filepath, line_num, line in matches[:20]:
            print(f"  {os.path.basename(filepath)}:{line_num}: {line}")

if __name__ == '__main__':
    search_files(r"c:\dukaanZone\flutter_app\lib", ["class MainHeader", "class AdminRail", "AdminRail"])
