# Marshall CA Tides Dashboard

A Python terminal-style interface that displays real-time environmental data for Marshall, CA including:

- **Current tide level** and whether it's rising or falling
- **Sunrise & sunset** times
- **Moonrise & moonset** times
- **Moon phase** with visual indicator
- **Temperature** and weather conditions
- **Precipitation forecast** (current, daily total, and probability)

## Installation

```bash
pip install -r requirements.txt
```

## Usage

Run the dashboard:

```bash
python marshall_tides.py
```

For demo mode (when APIs are unavailable):

```bash
python marshall_tides.py --demo
```

## Data Sources

- **Tides**: NOAA CO-OPS API (Point Reyes station - nearest to Marshall)
- **Weather**: Open-Meteo API (free, no API key required)
- **Sun/Moon**: Astral library (local calculations)

## Features

- Rich terminal UI with colored panels and icons
- Real-time data fetching from public APIs
- Automatic tide trend detection (rising/falling)
- Moon phase calculation with visual icons
- Comprehensive weather information

## Requirements

- Python 3.9+
- Internet connection (for live data)
- See `requirements.txt` for dependencies

## Location

Marshall, CA is located in Marin County on the shores of Tomales Bay.
- Latitude: 38.1574°N
- Longitude: 122.8894°W
