#!/usr/bin/env python3
"""
Marshall CA Tides Dashboard
A terminal-style interface displaying tide, weather, and astronomical data for Marshall, CA.
"""

import argparse
import requests
from datetime import datetime, timedelta
from zoneinfo import ZoneInfo
from astral import LocationInfo
from astral.sun import sun
from astral.moon import moonrise, moonset, phase
from rich.console import Console
from rich.table import Table
from rich.panel import Panel
from rich.layout import Layout
from rich.text import Text
from rich import box

# Marshall, CA coordinates
MARSHALL_LAT = 38.1574
MARSHALL_LON = -122.8894
TIMEZONE = ZoneInfo("America/Los_Angeles")

# Demo mode flag
DEMO_MODE = False

# NOAA Station ID for Point Reyes (nearest to Marshall, CA)
NOAA_STATION_ID = "9415020"  # Point Reyes, CA

# Common headers for API requests
HEADERS = {
    "User-Agent": "MarshallTidesDashboard/1.0 (Python; Educational Project)"
}

console = Console()


def get_tide_data():
    """Fetch current tide data from NOAA CO-OPS API."""
    if DEMO_MODE:
        # Demo data for testing display
        now = datetime.now(TIMEZONE)
        return {
            "current_level": 3.45,
            "trend": "Rising",
            "next_tide": 5.21,
            "next_tide_type": "High",
            "next_tide_time": now + timedelta(hours=3, minutes=42),
            "station": "Point Reyes (Demo)"
        }

    try:
        # Get predictions for today
        today = datetime.now(TIMEZONE)
        begin_date = today.strftime("%Y%m%d")
        end_date = (today + timedelta(days=1)).strftime("%Y%m%d")

        # Fetch tide predictions (high/low)
        url = "https://api.tidesandcurrents.noaa.gov/api/prod/datagetter"
        params = {
            "begin_date": begin_date,
            "end_date": end_date,
            "station": NOAA_STATION_ID,
            "product": "predictions",
            "datum": "MLLW",
            "time_zone": "lst_ldt",
            "units": "english",
            "interval": "hilo",
            "format": "json",
            "application": "MarshallTidesDashboard"
        }

        response = requests.get(url, params=params, headers=HEADERS, timeout=10)
        response.raise_for_status()
        hilo_data = response.json()

        # Fetch water level predictions at current time
        params["interval"] = "h"  # hourly predictions
        response = requests.get(url, params=params, headers=HEADERS, timeout=10)
        response.raise_for_status()
        hourly_data = response.json()

        # Process the data
        current_time = today
        current_level = None
        trend = "Unknown"
        next_tide = None
        next_tide_type = None
        next_tide_time = None

        # Find current water level from hourly predictions
        if "predictions" in hourly_data:
            predictions = hourly_data["predictions"]
            for i, pred in enumerate(predictions):
                pred_time = datetime.strptime(pred["t"], "%Y-%m-%d %H:%M")
                pred_time = pred_time.replace(tzinfo=TIMEZONE)

                if pred_time <= current_time:
                    current_level = float(pred["v"])
                    # Determine trend
                    if i + 1 < len(predictions):
                        next_level = float(predictions[i + 1]["v"])
                        if next_level > current_level:
                            trend = "Rising"
                        else:
                            trend = "Falling"

        # Find next high/low tide
        if "predictions" in hilo_data:
            for pred in hilo_data["predictions"]:
                pred_time = datetime.strptime(pred["t"], "%Y-%m-%d %H:%M")
                pred_time = pred_time.replace(tzinfo=TIMEZONE)

                if pred_time > current_time:
                    next_tide = float(pred["v"])
                    next_tide_type = "High" if pred["type"] == "H" else "Low"
                    next_tide_time = pred_time
                    break

        return {
            "current_level": current_level,
            "trend": trend,
            "next_tide": next_tide,
            "next_tide_type": next_tide_type,
            "next_tide_time": next_tide_time,
            "station": "Point Reyes"
        }

    except Exception as e:
        return {"error": str(e)}


def get_astronomical_data():
    """Calculate sunrise, sunset, moonrise, moonset, and moon phase."""
    try:
        location = LocationInfo(
            name="Marshall",
            region="CA",
            timezone="America/Los_Angeles",
            latitude=MARSHALL_LAT,
            longitude=MARSHALL_LON
        )

        today = datetime.now(TIMEZONE).date()

        # Sun data
        sun_data = sun(location.observer, date=today, tzinfo=TIMEZONE)

        # Moon data
        moon_rise = moonrise(location.observer, date=today, tzinfo=TIMEZONE)
        moon_set = moonset(location.observer, date=today, tzinfo=TIMEZONE)
        moon_phase_value = phase(today)

        # Determine moon phase name
        if moon_phase_value < 1.85:
            phase_name = "New Moon"
            phase_icon = "🌑"
        elif moon_phase_value < 5.55:
            phase_name = "Waxing Crescent"
            phase_icon = "🌒"
        elif moon_phase_value < 9.25:
            phase_name = "First Quarter"
            phase_icon = "🌓"
        elif moon_phase_value < 12.95:
            phase_name = "Waxing Gibbous"
            phase_icon = "🌔"
        elif moon_phase_value < 16.65:
            phase_name = "Full Moon"
            phase_icon = "🌕"
        elif moon_phase_value < 20.35:
            phase_name = "Waning Gibbous"
            phase_icon = "🌖"
        elif moon_phase_value < 24.05:
            phase_name = "Last Quarter"
            phase_icon = "🌗"
        else:
            phase_name = "Waning Crescent"
            phase_icon = "🌘"

        return {
            "sunrise": sun_data["sunrise"],
            "sunset": sun_data["sunset"],
            "moonrise": moon_rise,
            "moonset": moon_set,
            "moon_phase": phase_name,
            "moon_phase_icon": phase_icon,
            "moon_phase_value": moon_phase_value
        }

    except Exception as e:
        return {"error": str(e)}


def get_weather_data():
    """Fetch weather data from Open-Meteo API."""
    if DEMO_MODE:
        # Demo data for testing display
        return {
            "temperature": 58.3,
            "precipitation": 0.00,
            "weather_description": "Partly cloudy",
            "daily_precipitation": 0.12,
            "precipitation_probability": 35
        }

    try:
        url = "https://api.open-meteo.com/v1/forecast"
        params = {
            "latitude": MARSHALL_LAT,
            "longitude": MARSHALL_LON,
            "current": "temperature_2m,precipitation,weather_code",
            "hourly": "precipitation_probability",
            "daily": "precipitation_sum,precipitation_probability_max",
            "temperature_unit": "fahrenheit",
            "precipitation_unit": "inch",
            "timezone": "America/Los_Angeles",
            "forecast_days": 1
        }

        response = requests.get(url, params=params, headers=HEADERS, timeout=10)
        response.raise_for_status()
        data = response.json()

        current = data.get("current", {})
        daily = data.get("daily", {})

        # Weather code descriptions
        weather_codes = {
            0: "Clear sky",
            1: "Mainly clear",
            2: "Partly cloudy",
            3: "Overcast",
            45: "Foggy",
            48: "Depositing rime fog",
            51: "Light drizzle",
            53: "Moderate drizzle",
            55: "Dense drizzle",
            61: "Slight rain",
            63: "Moderate rain",
            65: "Heavy rain",
            71: "Slight snow",
            73: "Moderate snow",
            75: "Heavy snow",
            77: "Snow grains",
            80: "Slight rain showers",
            81: "Moderate rain showers",
            82: "Violent rain showers",
            85: "Slight snow showers",
            86: "Heavy snow showers",
            95: "Thunderstorm",
            96: "Thunderstorm with slight hail",
            99: "Thunderstorm with heavy hail"
        }

        weather_code = current.get("weather_code", 0)

        return {
            "temperature": current.get("temperature_2m"),
            "precipitation": current.get("precipitation", 0),
            "weather_description": weather_codes.get(weather_code, "Unknown"),
            "daily_precipitation": daily.get("precipitation_sum", [0])[0] if daily.get("precipitation_sum") else 0,
            "precipitation_probability": daily.get("precipitation_probability_max", [0])[0] if daily.get("precipitation_probability_max") else 0
        }

    except Exception as e:
        return {"error": str(e)}


def create_tide_panel(tide_data):
    """Create a panel displaying tide information."""
    if "error" in tide_data:
        return Panel(f"[red]Error fetching tide data: {tide_data['error']}[/red]", title="🌊 Tides", border_style="blue")

    table = Table(show_header=False, box=None, padding=(0, 1))
    table.add_column("Label", style="cyan")
    table.add_column("Value", style="white")

    if tide_data["current_level"] is not None:
        level_str = f"{tide_data['current_level']:.2f} ft"
    else:
        level_str = "N/A"

    trend_color = "green" if tide_data["trend"] == "Rising" else "red" if tide_data["trend"] == "Falling" else "yellow"
    trend_arrow = "↑" if tide_data["trend"] == "Rising" else "↓" if tide_data["trend"] == "Falling" else "?"

    table.add_row("Current Level:", level_str)
    table.add_row("Status:", f"[{trend_color}]{trend_arrow} {tide_data['trend']}[/{trend_color}]")
    table.add_row("Station:", tide_data["station"])

    if tide_data["next_tide_time"]:
        time_str = tide_data["next_tide_time"].strftime("%I:%M %p")
        table.add_row(f"Next {tide_data['next_tide_type']}:", f"{tide_data['next_tide']:.2f} ft @ {time_str}")

    return Panel(table, title="🌊 Tides", border_style="blue", padding=(1, 2))


def create_sun_moon_panel(astro_data):
    """Create a panel displaying astronomical information."""
    if "error" in astro_data:
        return Panel(f"[red]Error: {astro_data['error']}[/red]", title="☀️ Sun & Moon", border_style="yellow")

    table = Table(show_header=False, box=None, padding=(0, 1))
    table.add_column("Label", style="cyan")
    table.add_column("Value", style="white")

    # Sun times
    sunrise_str = astro_data["sunrise"].strftime("%I:%M %p")
    sunset_str = astro_data["sunset"].strftime("%I:%M %p")

    table.add_row("☀️  Sunrise:", sunrise_str)
    table.add_row("🌅 Sunset:", sunset_str)
    table.add_row("", "")

    # Moon times
    if astro_data["moonrise"]:
        moonrise_str = astro_data["moonrise"].strftime("%I:%M %p")
    else:
        moonrise_str = "No moonrise today"

    if astro_data["moonset"]:
        moonset_str = astro_data["moonset"].strftime("%I:%M %p")
    else:
        moonset_str = "No moonset today"

    table.add_row("🌙 Moonrise:", moonrise_str)
    table.add_row("🌙 Moonset:", moonset_str)
    table.add_row("", "")

    # Moon phase
    table.add_row("Moon Phase:", f"{astro_data['moon_phase_icon']} {astro_data['moon_phase']}")

    return Panel(table, title="☀️ Sun & Moon", border_style="yellow", padding=(1, 2))


def create_weather_panel(weather_data):
    """Create a panel displaying weather information."""
    if "error" in weather_data:
        return Panel(f"[red]Error: {weather_data['error']}[/red]", title="🌡️ Weather", border_style="green")

    table = Table(show_header=False, box=None, padding=(0, 1))
    table.add_column("Label", style="cyan")
    table.add_column("Value", style="white")

    temp = weather_data["temperature"]
    if temp is not None:
        table.add_row("Temperature:", f"{temp:.1f}°F")
    else:
        table.add_row("Temperature:", "N/A")

    table.add_row("Conditions:", weather_data["weather_description"])
    table.add_row("", "")

    # Precipitation
    precip = weather_data["precipitation"]
    daily_precip = weather_data["daily_precipitation"]
    precip_prob = weather_data["precipitation_probability"]

    table.add_row("Current Precip:", f"{precip:.2f} in")
    table.add_row("Daily Forecast:", f"{daily_precip:.2f} in")
    table.add_row("Chance of Rain:", f"{precip_prob}%")

    return Panel(table, title="🌡️ Weather", border_style="green", padding=(1, 2))


def display_dashboard():
    """Display the complete dashboard."""
    console.clear()

    # Header
    now = datetime.now(TIMEZONE)
    header_text = Text()
    header_text.append("MARSHALL, CA - TIDES & WEATHER DASHBOARD\n", style="bold white on blue")
    header_text.append(f"Updated: {now.strftime('%A, %B %d, %Y at %I:%M:%S %p %Z')}", style="dim")

    header = Panel(header_text, box=box.DOUBLE, border_style="bright_blue", padding=(0, 1))
    console.print(header)
    console.print()

    # Fetch all data
    with console.status("[bold green]Fetching tide data...[/bold green]"):
        tide_data = get_tide_data()

    with console.status("[bold yellow]Calculating astronomical data...[/bold yellow]"):
        astro_data = get_astronomical_data()

    with console.status("[bold cyan]Fetching weather data...[/bold cyan]"):
        weather_data = get_weather_data()

    # Create and display panels
    tide_panel = create_tide_panel(tide_data)
    sun_moon_panel = create_sun_moon_panel(astro_data)
    weather_panel = create_weather_panel(weather_data)

    # Display in a nice layout
    console.print(tide_panel)
    console.print(sun_moon_panel)
    console.print(weather_panel)

    # Footer
    console.print()
    footer = Panel(
        "[dim]Data sources: NOAA CO-OPS (tides), Open-Meteo (weather), Astral library (sun/moon)[/dim]\n"
        "[dim]Tide station: Point Reyes, CA (nearest to Marshall)[/dim]",
        border_style="dim",
        padding=(0, 1)
    )
    console.print(footer)


def main():
    """Main entry point."""
    global DEMO_MODE

    parser = argparse.ArgumentParser(description="Marshall CA Tides & Weather Dashboard")
    parser.add_argument(
        "--demo",
        action="store_true",
        help="Run in demo mode with sample data (useful when APIs are unavailable)"
    )
    args = parser.parse_args()

    DEMO_MODE = args.demo

    try:
        display_dashboard()
    except KeyboardInterrupt:
        console.print("\n[yellow]Dashboard closed.[/yellow]")
    except Exception as e:
        console.print(f"[red]Error: {e}[/red]")
        raise


if __name__ == "__main__":
    main()
