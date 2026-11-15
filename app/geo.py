"""Countries, languages and YouTube categories used by campaigns."""

# code: (name, time zone, how people there write)
COUNTRIES = {
    'US': ('United States', 'America/New_York', 'American English spelling and slang'),
    'GB': ('United Kingdom', 'Europe/London', 'British English spelling and slang'),
    'CA': ('Canada', 'America/Toronto', 'Canadian English'),
    'AU': ('Australia', 'Australia/Sydney', 'Australian English spelling and slang'),
    'NZ': ('New Zealand', 'Pacific/Auckland', 'New Zealand English'),
    'IE': ('Ireland', 'Europe/Dublin', 'Irish English'),
    'IN': ('India', 'Asia/Kolkata', 'Indian English or Hinglish'),
    'PK': ('Pakistan', 'Asia/Karachi', 'Pakistani English or Roman Urdu'),
    'BD': ('Bangladesh', 'Asia/Dhaka', 'simple English'),
    'AE': ('United Arab Emirates', 'Asia/Dubai', 'simple international English'),
    'SA': ('Saudi Arabia', 'Asia/Riyadh', 'simple international English or Arabic'),
    'PH': ('Philippines', 'Asia/Manila', 'Filipino English'),
    'NG': ('Nigeria', 'Africa/Lagos', 'Nigerian English'),
    'ZA': ('South Africa', 'Africa/Johannesburg', 'South African English'),
    'DE': ('Germany', 'Europe/Berlin', 'German'),
    'FR': ('France', 'Europe/Paris', 'French'),
    'ES': ('Spain', 'Europe/Madrid', 'Spanish (Spain)'),
    'MX': ('Mexico', 'America/Mexico_City', 'Mexican Spanish'),
    'BR': ('Brazil', 'America/Sao_Paulo', 'Brazilian Portuguese'),
    'ID': ('Indonesia', 'Asia/Jakarta', 'Indonesian'),
    'TR': ('Turkey', 'Europe/Istanbul', 'Turkish'),
    'WW': ('Worldwide', 'UTC', 'simple international English'),
}

LANGS = {
    'en': 'English', 'hi': 'Hindi', 'ur': 'Urdu', 'es': 'Spanish', 'pt': 'Portuguese', 'fr': 'French', 'de': 'German',
    'ar': 'Arabic', 'id': 'Indonesian', 'tr': 'Turkish', 'ru': 'Russian', 'it': 'Italian', 'bn': 'Bengali',
    'pa': 'Punjabi', 'ja': 'Japanese', 'ko': 'Korean', 'nl': 'Dutch', 'pl': 'Polish', 'vi': 'Vietnamese', 'th': 'Thai',
}

CATEGORIES = {
    '24': 'Entertainment', '20': 'Gaming', '17': 'Sports', '22': 'People & Blogs', '23': 'Comedy', '27': 'Education',
    '28': 'Science & Technology', '26': 'Howto & Style', '25': 'News & Politics', '10': 'Music', '1': 'Film & Animation',
    '2': 'Autos & Vehicles', '15': 'Pets & Animals', '19': 'Travel & Events',
}

# Local clock hours that get the most Shorts views, best first, by how many posts a day.
PEAK_HOURS = {1: [19], 2: [12, 19], 3: [12, 17, 20], 4: [9, 13, 17, 20], 5: [8, 12, 15, 18, 21],
              6: [8, 11, 14, 17, 19, 21], 7: [8, 10, 12, 14, 17, 19, 21], 8: [7, 9, 11, 13, 15, 17, 19, 21]}


def peak_hours(per_day):
    per_day = max(1, int(per_day))
    if per_day in PEAK_HOURS:
        return PEAK_HOURS[per_day]
    step = 16 / per_day  # spread between 7:00 and 23:00
    return [round(7 + i * step, 2) for i in range(per_day)]


def country_name(code):
    return COUNTRIES.get(code, COUNTRIES['WW'])[0]


def tz_name(code):
    return COUNTRIES.get(code, COUNTRIES['WW'])[1]


def lang_name(code):
    return LANGS.get((code or '').split('-')[0], code or 'the same language as the video')
