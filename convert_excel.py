import pandas as pd
import json

df = pd.read_excel(r'c:\Users\salma\Downloads\Ayat.xls')

surahs = {}
for _, row in df.iterrows():
    surah_num = int(row['السورة'])
    if surah_num not in surahs:
        surahs[surah_num] = {
            'ayahs': [],
            'total_ayahs': 0,
            'juz': int(row['رقم الجزء']),
            'page_start': int(row['رقم الصفحة'])
        }
    
    ayah = {
        'id': int(row['المعرف']),
        'number': int(row['رقم الآية']),
        'text': str(row['نص الآية']) if pd.notna(row['نص الآية']) else '',
        'page': int(row['رقم الصفحة']),
        'juz': int(row['رقم الجزء']),
        'hizb': int(row['رقم الحزب']),
        'quarter': int(row['رقم الربع']),
        'lines': float(row['عدد الأسطر']) if pd.notna(row['عدد الأسطر']) else 0,
        'difficulty': int(row['درجة السهولة']) if pd.notna(row['درجة السهولة']) else 0
    }
    surahs[surah_num]['ayahs'].append(ayah)
    surahs[surah_num]['total_ayahs'] = len(surahs[surah_num]['ayahs'])

surah_names = [
    "", "الفاتحة", "البقرة", "آل عمران", "النساء", "المائدة", "الأنعام", "الأعراف", "الأنفال", "التوبة", "يونس",
    "هود", "يوسف", "الرعد", "إبراهيم", "الحجر", "النحل", "الإسراء", "الكهف", "مريم", "طه",
    "الأنبياء", "الحج", "المؤمنون", "النور", "الفرقان", "الشعراء", "النمل", "القصص", "العنكبوت", "الروم",
    "لقمان", "السجدة", "الأحزاب", "سبأ", "فاطر", "يس", "الصافات", "ص", "الزمر", "غافر",
    "فصلت", "الشورى", "الزخرف", "الدخان", "الجاثية", "الأحقاف", "محمد", "الفتح", "الحجرات", "ق",
    "الذاريات", "الطور", "النجم", "القمر", "الرحمن", "الواقعة", "الحديد", "المجادلة", "الحشر", "الممتحنة",
    "الصف", "الجمعة", "المنافقون", "التغابن", "الطلاق", "التحريم", "الملك", "القلم", "الحاقة", "المعارج",
    "نوح", "الجن", "المزمل", "المدثر", "القيامة", "الإنسان", "المرسلات", "النبأ", "النازعات", "عبس",
    "التكوير", "الانفطار", "المطففين", "الانشقاق", "البروج", "الطارق", "الأعلى", "الغاشية", "الفجر", "البلد",
    "الشمس", "الليل", "الضحى", "الشرح", "التين", "العلق", "القدر", "البينة", "الزلزلة", "العاديات",
    "القارعة", "التكاثر", "العصر", "الهمزة", "الفيل", "قريش", "الماعون", "الكوثر", "الكافرون", "النصر",
    "المسد", "الإخلاص", "الفلق", "الناس"
]

quran_data = {
    'total_ayahs': 6236,
    'total_surahs': 114,
    'total_pages': 604,
    'total_juz': 30,
    'surahs': []
}

for surah_num in range(1, 115):
    surah_info = surahs.get(surah_num, {'ayahs': [], 'juz': 1, 'page_start': 1})
    quran_data['surahs'].append({
        'number': surah_num,
        'name': surah_names[surah_num],
        'total_ayahs': len(surah_info['ayahs']),
        'juz_start': surah_info['juz'],
        'page_start': surah_info['page_start'],
        'ayahs': surah_info['ayahs']
    })

with open(r'c:\Users\salma\flutter_App\Halaqah\assets\quran_data.json', 'w', encoding='utf-8') as f:
    json.dump(quran_data, f, ensure_ascii=False, indent=2)

print(f"Done! Total surahs: {len(quran_data['surahs'])}")
print(f"Total ayahs exported: {sum(len(s['ayahs']) for s in quran_data['surahs'])}")
