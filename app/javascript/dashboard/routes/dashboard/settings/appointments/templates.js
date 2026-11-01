// Ready-made setups by type of business. Hours use the same shape as the server:
// { weekday: [[from, to], ...] } with Sunday = 0; two ranges mean a break in between.
const everyDay = (days, ranges) =>
  Object.fromEntries(days.map(day => [String(day), ranges]));

const MON_SAT = [1, 2, 3, 4, 5, 6];
const ALL_WEEK = [0, 1, 2, 3, 4, 5, 6];

export default [
  {
    key: 'CLINIC',
    icon: 'i-lucide-stethoscope',
    setting: {
      hours: everyDay(MON_SAT, [
        ['09:00', '13:00'],
        ['17:00', '21:00'],
      ]),
      slot_minutes: 15,
      capacity: 1,
      days_ahead: 14,
      min_notice_minutes: 60,
      services: [
        { name: 'Consultation', minutes: 15, price: '' },
        { name: 'Follow-up visit', minutes: 15, price: '' },
      ],
    },
  },
  {
    key: 'SALON',
    icon: 'i-lucide-scissors',
    setting: {
      hours: everyDay(ALL_WEEK, [['11:00', '21:00']]),
      slot_minutes: 30,
      capacity: 2,
      days_ahead: 30,
      min_notice_minutes: 60,
      services: [
        { name: 'Haircut', minutes: 30, price: '' },
        { name: 'Facial', minutes: 60, price: '' },
        { name: 'Bridal makeup', minutes: 120, price: '' },
      ],
    },
  },
  {
    key: 'CONSULTANT',
    icon: 'i-lucide-briefcase',
    setting: {
      hours: everyDay(
        [1, 2, 3, 4, 5],
        [
          ['10:00', '13:00'],
          ['14:00', '17:00'],
        ]
      ),
      slot_minutes: 60,
      capacity: 1,
      days_ahead: 21,
      min_notice_minutes: 240,
      services: [{ name: 'Consultation', minutes: 60, price: '' }],
    },
  },
  {
    key: 'PROPERTY',
    icon: 'i-lucide-house',
    setting: {
      hours: everyDay(ALL_WEEK, [['11:00', '18:00']]),
      slot_minutes: 60,
      capacity: 1,
      days_ahead: 14,
      min_notice_minutes: 120,
      services: [{ name: 'Property visit', minutes: 60, price: '' }],
    },
  },
  {
    key: 'RESTAURANT',
    icon: 'i-lucide-utensils',
    setting: {
      hours: everyDay(ALL_WEEK, [['12:00', '23:00']]),
      slot_minutes: 30,
      capacity: 10,
      days_ahead: 14,
      min_notice_minutes: 60,
      services: [{ name: 'Table booking', minutes: 90, price: '' }],
    },
  },
];
