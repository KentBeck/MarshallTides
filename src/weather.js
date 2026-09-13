// Open-Meteo forecast (no key, CORS-friendly) for the station.

import { TZ, parseWall } from './time.js';

const API = 'https://api.open-meteo.com/v1/forecast';

export function forecastUrl(lat, lng) {
  const q = new URLSearchParams({
    latitude: lat, longitude: lng,
    current: 'temperature_2m,apparent_temperature,wind_speed_10m,wind_direction_10m,wind_gusts_10m,weather_code,is_day',
    hourly: 'temperature_2m,wind_speed_10m,wind_direction_10m,wind_gusts_10m,weather_code,precipitation_probability,is_day',
    daily: 'temperature_2m_max,temperature_2m_min,weather_code,wind_speed_10m_max',
    temperature_unit: 'fahrenheit', wind_speed_unit: 'mph',
    timezone: TZ, forecast_days: '3',
  });
  return `${API}?${q}`;
}

export function parseForecast(j) {
  const c = j.current, h = j.hourly, d = j.daily;
  return {
    current: {
      time: parseWall(c.time), temp: c.temperature_2m, feels: c.apparent_temperature,
      wind: c.wind_speed_10m, gust: c.wind_gusts_10m, dir: c.wind_direction_10m,
      code: c.weather_code, isDay: c.is_day === 1,
    },
    hourly: h.time.map((t, i) => ({
      time: parseWall(t), temp: h.temperature_2m[i], wind: h.wind_speed_10m[i],
      gust: h.wind_gusts_10m[i], dir: h.wind_direction_10m[i], code: h.weather_code[i],
      precip: h.precipitation_probability[i], isDay: h.is_day[i] === 1,
    })),
    daily: d.time.map((t, i) => ({
      time: parseWall(t), hi: d.temperature_2m_max[i], lo: d.temperature_2m_min[i],
      code: d.weather_code[i], windMax: d.wind_speed_10m_max[i],
    })),
  };
}

export async function fetchForecast(lat, lng, fetchImpl = fetch) {
  const res = await fetchImpl(forecastUrl(lat, lng));
  if (!res.ok) throw new Error(`Open-Meteo ${res.status}`);
  return parseForecast(await res.json());
}

// WMO weather codes -> label and icon id.
const CODES = [
  [0, 'Clear', 'sun'], [1, 'Mostly clear', 'sun'], [2, 'Partly cloudy', 'partly'], [3, 'Overcast', 'cloud'],
  [45, 'Fog', 'fog'], [48, 'Freezing fog', 'fog'],
  [51, 'Light drizzle', 'drizzle'], [53, 'Drizzle', 'drizzle'], [55, 'Heavy drizzle', 'drizzle'],
  [56, 'Freezing drizzle', 'drizzle'], [57, 'Freezing drizzle', 'drizzle'],
  [61, 'Light rain', 'rain'], [63, 'Rain', 'rain'], [65, 'Heavy rain', 'rain'],
  [66, 'Freezing rain', 'rain'], [67, 'Freezing rain', 'rain'],
  [71, 'Light snow', 'snow'], [73, 'Snow', 'snow'], [75, 'Heavy snow', 'snow'], [77, 'Snow grains', 'snow'],
  [80, 'Light showers', 'rain'], [81, 'Showers', 'rain'], [82, 'Heavy showers', 'rain'],
  [85, 'Snow showers', 'snow'], [86, 'Snow showers', 'snow'],
  [95, 'Thunderstorm', 'storm'], [96, 'Thunderstorm, hail', 'storm'], [99, 'Thunderstorm, hail', 'storm'],
];

export function describeCode(code, isDay = true) {
  const row = CODES.find(r => r[0] === code) || [code, 'Unknown', 'cloud'];
  let icon = row[2];
  if (!isDay && icon === 'sun') icon = 'moon';
  if (!isDay && icon === 'partly') icon = 'partly-night';
  return { label: row[1], icon };
}

const POINTS = ['N', 'NNE', 'NE', 'ENE', 'E', 'ESE', 'SE', 'SSE', 'S', 'SSW', 'SW', 'WSW', 'W', 'WNW', 'NW', 'NNW'];
export const compass = deg => POINTS[Math.round(((deg % 360) + 360) % 360 / 22.5) % 16];
