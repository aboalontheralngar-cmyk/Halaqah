import pandas as pd
import json
import sys

sys.stdout.reconfigure(encoding='utf-8')
df = pd.read_excel(r'c:\Users\salma\Downloads\Ayat.xls')

# Save to JSON file for inspection
output = {
    'columns': df.columns.tolist(),
    'total_rows': len(df),
    'sample_5': df.head(5).to_dict('records'),
    'sample_last_5': df.tail(5).to_dict('records')
}

with open('ayat_structure.json', 'w', encoding='utf-8') as f:
    json.dump(output, f, ensure_ascii=False, indent=2, default=str)

print("Done! Check ayat_structure.json")
