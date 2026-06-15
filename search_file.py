import os

directory = r"c:\dukaanZone\flutter_app\lib"
for root, dirs, files in os.walk(directory):
    for file in files:
        if file.endswith('.dart'):
            filepath = os.path.join(root, file)
            try:
                with open(filepath, 'r', encoding='utf-8') as f:
                    for line_num, line in enumerate(f, 1):
                        if "class " in line and "Chat" in line:
                            print(f"{filepath}:{line_num}: {line.strip()}")
            except Exception as e:
                pass
