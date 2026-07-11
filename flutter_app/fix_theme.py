import os, glob

ui_dir = r'c:\dukaanZone\flutter_app\lib\ui'
files = glob.glob(os.path.join(ui_dir, '**', '*.dart'), recursive=True)

for file in files:
    with open(file, 'r', encoding='utf-8') as f:
        lines = f.readlines()
    
    modified = False
    new_lines = []
    for line in lines:
        if line.strip() == 'backgroundColor: Colors.white,':
            modified = True
            continue # skip this line
        new_lines.append(line)
        
    if modified:
        with open(file, 'w', encoding='utf-8') as f:
            f.writelines(new_lines)
        print(f"Fixed theme in {file}")
