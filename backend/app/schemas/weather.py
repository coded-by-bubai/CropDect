from pydantic import BaseModel
from typing import List

class DailyForecast(BaseModel):
    date: str
    max_temp_c: float
    min_temp_c: float
    precipitation_sum_mm: float
    et0_mm: float

class WeatherResponse(BaseModel):
    farm_id: int
    current_temp_c: float
    current_humidity_percent: float
    current_precipitation_mm: float
    current_wind_speed_kmh: float
    current_soil_moisture: float
    current_weather_code: int
    forecast: List[DailyForecast]
    risk_level: str
