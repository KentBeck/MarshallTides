// Offline sample, shaped exactly like the NOAA and Open-Meteo responses so
// the same parsers run. Used when the live fetch fails (or with ?sample).
// The tide numbers are plausible for Tomales Bay two days after a new moon;
// they are not a forecast.

const NOW = '2026-09-13T18:30:00Z'; // 11:30 AM PDT, Sunday

const predictions = [
  ['2026-09-12 07:10', '5.0', 'H'], ['2026-09-12 13:00', '2.3', 'L'],
  ['2026-09-12 19:30', '6.0', 'H'], ['2026-09-13 02:00', '1.2', 'L'],
  ['2026-09-13 07:40', '5.4', 'H'], ['2026-09-13 13:50', '1.9', 'L'],
  ['2026-09-13 20:10', '6.3', 'H'], ['2026-09-14 02:50', '0.9', 'L'],
  ['2026-09-14 09:30', '4.6', 'H'], ['2026-09-14 15:40', '1.7', 'L'],
  ['2026-09-14 21:10', '5.9', 'H'], ['2026-09-15 04:00', '0.6', 'L'],
  ['2026-09-15 10:40', '4.4', 'H'], ['2026-09-15 16:40', '1.9', 'L'],
  ['2026-09-15 22:00', '5.7', 'H'], ['2026-09-16 04:50', '0.5', 'L'],
].map(([t, v, type]) => ({ t, v, type }));

// A September pattern: fog until late morning, clearing, north-west wind
// building through the afternoon and dropping off after sunset.
function hourly() {
  const time = [], temperature_2m = [], wind_speed_10m = [], wind_direction_10m = [],
    wind_gusts_10m = [], weather_code = [], precipitation_probability = [], is_day = [];
  const days = ['2026-09-13', '2026-09-14', '2026-09-15'];
  days.forEach((day, di) => {
    for (let h = 0; h < 24; h++) {
      const warm = Math.max(0, Math.sin(Math.PI * (h - 7) / 13));
      const breeze = Math.max(0, Math.sin(Math.PI * (h - 10) / 10));
      time.push(`${day}T${String(h).padStart(2, '0')}:00`);
      temperature_2m.push(Math.round((53 + 13 * warm - di) * 10) / 10);
      wind_speed_10m.push(Math.round(4 + 12 * breeze));
      wind_gusts_10m.push(Math.round(7 + 17 * breeze));
      wind_direction_10m.push(Math.round(305 + 20 * Math.sin(h / 3)));
      const clearBy = di === 1 ? 13 : 11;
      weather_code.push(h < clearBy - 2 ? 45 : h < clearBy ? 3 : h < clearBy + 1 ? 2 : h < 20 ? 0 : 2);
      precipitation_probability.push(0);
      is_day.push(h >= 7 && h < 19 ? 1 : 0);
    }
  });
  return { time, temperature_2m, wind_speed_10m, wind_direction_10m, wind_gusts_10m, weather_code, precipitation_probability, is_day };
}

export const SAMPLE = {
  now: NOW,
  predictions: { predictions },
  forecast: {
    current: {
      time: '2026-09-13T11:30', temperature_2m: 61.3, apparent_temperature: 59.1,
      wind_speed_10m: 9, wind_direction_10m: 312, wind_gusts_10m: 15, weather_code: 2, is_day: 1,
    },
    hourly: hourly(),
    daily: {
      time: ['2026-09-13', '2026-09-14', '2026-09-15'],
      temperature_2m_max: [66.2, 64.9, 63.5],
      temperature_2m_min: [52.7, 52.1, 51.8],
      weather_code: [2, 3, 2],
      wind_speed_10m_max: [16, 15, 14],
    },
  },
};
