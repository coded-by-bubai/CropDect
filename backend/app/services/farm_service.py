from typing import List, Optional
from sqlalchemy.orm import Session
from app.models.farm import Farm
from app.schemas.farm import FarmCreate, FarmUpdate
from geoalchemy2.shape import to_shape
import shapely.geometry

def _enrich_farm(farm: Farm) -> Farm:
    """Helper to attach latitude and longitude directly to the farm object before Pydantic parsing."""
    if not farm:
        return farm
    farm.longitude = 0.0
    farm.latitude = 0.0
    if farm.location is not None:
        try:
            point = to_shape(farm.location)
            farm.longitude = float(point.x)
            farm.latitude = float(point.y)
        except Exception:
            farm.longitude = 0.0
            farm.latitude = 0.0
    return farm

def get_farm(db: Session, farm_id: int, owner_id: int) -> Optional[Farm]:
    farm = db.query(Farm).filter(Farm.id == farm_id, Farm.owner_id == owner_id).first()
    return _enrich_farm(farm) if farm else None

def get_farms(db: Session, owner_id: int, skip: int = 0, limit: int = 100) -> List[Farm]:
    farms = db.query(Farm).filter(Farm.owner_id == owner_id).offset(skip).limit(limit).all()
    return [_enrich_farm(f) for f in farms]

def create_farm(db: Session, farm_in: FarmCreate, owner_id: int) -> Farm:
    try:
        lat = float(farm_in.latitude) if farm_in.latitude is not None else 0.0
        lng = float(farm_in.longitude) if farm_in.longitude is not None else 0.0
        if not (-90.0 <= lat <= 90.0 and -180.0 <= lng <= 180.0):
            lat, lng = 0.0, 0.0
        wkt_point = f"POINT({lng} {lat})"
    except Exception:
        wkt_point = "POINT(0 0)"

    db_farm = Farm(
        owner_id=owner_id,
        name=farm_in.name,
        area=farm_in.area,
        soil_type=farm_in.soil_type,
        location=wkt_point
    )
    db.add(db_farm)
    db.commit()
    db.refresh(db_farm)
    return _enrich_farm(db_farm)

def update_farm(db: Session, db_farm: Farm, farm_in: FarmUpdate) -> Farm:
    update_data = farm_in.model_dump(exclude_unset=True)
    if 'latitude' in update_data or 'longitude' in update_data:
        try:
            lat = float(update_data.get('latitude', 0.0) or 0.0)
            lng = float(update_data.get('longitude', 0.0) or 0.0)
            if -90.0 <= lat <= 90.0 and -180.0 <= lng <= 180.0:
                db_farm.location = f"POINT({lng} {lat})"
            else:
                db_farm.location = "POINT(0 0)"
        except Exception:
            db_farm.location = "POINT(0 0)"
        update_data.pop('latitude', None)
        update_data.pop('longitude', None)
    
    for field in update_data:
        setattr(db_farm, field, update_data[field])
        
    db.add(db_farm)
    db.commit()
    db.refresh(db_farm)
    return _enrich_farm(db_farm)

def delete_farm(db: Session, db_farm: Farm) -> Farm:
    db.delete(db_farm)
    db.commit()
    return db_farm
