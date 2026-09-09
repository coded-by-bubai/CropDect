import httpx
from sqlalchemy.orm import Session
from app.models.farm import Farm
from sqlalchemy import func, cast
from geoalchemy2.types import Geometry
from app.schemas.weather import WeatherResponse, DailyForecast
from fastapi import HTTPException

def fetch_weather_for_farm(db: Session, farm_id: int, owner_id: int) -> WeatherResponse:
    farm = db.query(
        Farm.id,
        func.ST_Y(cast(Farm.location, Geometry)).label('latitude'),
        func.ST_X(cast(Farm.location, Geometry)).label('longitude')
    ).filter(Farm.id == farm_id, Farm.owner_id == owner_id).first()
    
    if not farm:
        raise HTTPException(status_code=404, detail="Farm not found or access denied")
        
    lat = farm.latitude
    lng = farm.longitude
    
    # Return error if location coordinates are missing or invalid
    if lat is None or lng is None or not (-90.0 <= lat <= 90.0 and -180.0 <= lng <= 180.0) or (lat == 0.0 and lng == 0.0):
        raise HTTPException(status_code=400, detail="Farm location not set")
        
    url = f"https://api.open-meteo.com/v1/forecast?latitude={lat}&longitude={lng}&current=temperature_2m,relative_humidity_2m,precipitation,wind_speed_10m,weather_code&hourly=soil_moisture_0_to_7cm&daily=temperature_2m_max,temperature_2m_min,precipitation_sum,et0_fao_evapotranspiration&timezone=auto"
    
    try:
        with httpx.Client() as client:
            response = client.get(url, timeout=10.0)
            response.raise_for_status()
            data = response.json()
            
            current = data.get("current", {})
            daily = data.get("daily", {})
            
            forecast_list = []
            if daily:
                for i in range(min(7, len(daily.get("time", [])))):
                    forecast_list.append(DailyForecast(
                        date=daily["time"][i],
                        max_temp_c=daily["temperature_2m_max"][i],
                        min_temp_c=daily["temperature_2m_min"][i],
                        precipitation_sum_mm=daily["precipitation_sum"][i],
                        et0_mm=daily["et0_fao_evapotranspiration"][i]
                    ))
            
            hourly = data.get("hourly", {})
            curr_hum = current.get("relative_humidity_2m", 0)
            curr_prec = current.get("precipitation", 0)
            curr_wind = current.get("wind_speed_10m", 0)
            curr_code = current.get("weather_code", 0)
            curr_soil = hourly.get("soil_moisture_0_to_7cm", [0.0])[0] if hourly and "soil_moisture_0_to_7cm" in hourly else 0.0
            
            risk_level = "Low"
            if curr_hum > 80 or curr_prec > 5:
                risk_level = "High Fungal Risk"
            elif curr_hum < 30 and current.get("temperature_2m", 0) > 30:
                risk_level = "High Pest Risk"
                
            return WeatherResponse(
                farm_id=farm_id,
                current_temp_c=current.get("temperature_2m", 0),
                current_humidity_percent=curr_hum,
                current_precipitation_mm=curr_prec,
                current_wind_speed_kmh=curr_wind,
                current_soil_moisture=curr_soil,
                current_weather_code=curr_code,
                forecast=forecast_list,
                risk_level=risk_level
            )
    except Exception as e:
        print(f"Weather API failed: {e}")
        return WeatherResponse(
            farm_id=farm_id,
            current_temp_c=25.0,
            current_humidity_percent=50.0,
            current_precipitation_mm=0.0,
            current_wind_speed_kmh=0.0,
            current_soil_moisture=0.0,
            current_weather_code=0,
            forecast=[],
            risk_level="UNKNOWN (Weather API Unavailable)"
        )
