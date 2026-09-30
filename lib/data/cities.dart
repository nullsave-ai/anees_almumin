class City {
  const City(this.name, this.lat, this.lng, this.tz);
  final String name;
  final double lat;
  final double lng;
  final String tz;
}

const cities = <City>[
  City('مكة المكرمة', 21.4225, 39.8262, 'Asia/Riyadh'),
  City('المدينة المنورة', 24.4686, 39.6142, 'Asia/Riyadh'),
  City('الرياض', 24.7136, 46.6753, 'Asia/Riyadh'),
  City('جدة', 21.4858, 39.1925, 'Asia/Riyadh'),
  City('الدمام', 26.4207, 50.0888, 'Asia/Riyadh'),
  City('القاهرة', 30.0444, 31.2357, 'Africa/Cairo'),
  City('الإسكندرية', 31.2001, 29.9187, 'Africa/Cairo'),
  City('دبي', 25.2048, 55.2708, 'Asia/Dubai'),
  City('أبوظبي', 24.4539, 54.3773, 'Asia/Dubai'),
  City('الدوحة', 25.2854, 51.5310, 'Asia/Qatar'),
  City('مدينة الكويت', 29.3759, 47.9774, 'Asia/Kuwait'),
  City('المنامة', 26.2285, 50.5860, 'Asia/Bahrain'),
  City('مسقط', 23.5880, 58.3829, 'Asia/Muscat'),
  City('عمّان', 31.9454, 35.9284, 'Asia/Amman'),
  City('بغداد', 33.3152, 44.3661, 'Asia/Baghdad'),
  City('دمشق', 33.5138, 36.2765, 'Asia/Damascus'),
  City('بيروت', 33.8938, 35.5018, 'Asia/Beirut'),
  City('القدس', 31.7683, 35.2137, 'Asia/Jerusalem'),
  City('صنعاء', 15.3694, 44.1910, 'Asia/Aden'),
  City('الخرطوم', 15.5007, 32.5599, 'Africa/Khartoum'),
  City('طرابلس', 32.8872, 13.1913, 'Africa/Tripoli'),
  City('تونس', 36.8065, 10.1815, 'Africa/Tunis'),
  City('الجزائر', 36.7538, 3.0588, 'Africa/Algiers'),
  City('الرباط', 34.0209, -6.8416, 'Africa/Casablanca'),
  City('الدار البيضاء', 33.5731, -7.5898, 'Africa/Casablanca'),
  City('إسطنبول', 41.0082, 28.9784, 'Europe/Istanbul'),
];
