from sqlalchemy.orm import Session
from sqlalchemy import func, cast
from geoalchemy2.types import Geography, Geometry
from app.models.diagnosis import DiagnosisReport, DiagnosisStatus
from app.models.crop import Crop
from app.models.farm import Farm
from app.models.knowledge_base import KnowledgeBase
from app.schemas.hotspot import HotspotResponse, HotspotLocation, OutbreakCluster
from typing import Optional
from sklearn.cluster import DBSCAN
import numpy as np
from collections import defaultdict
from math import radians

def get_disease_hotspots(
    db: Session, 
    disease_name: Optional[str] = None, 
    radius_km: Optional[float] = None, 
    lat: Optional[float] = None, 
    lng: Optional[float] = None
) -> HotspotResponse:
    
    loc_col = func.coalesce(DiagnosisReport.location, Farm.location)

    query = db.query(
        DiagnosisReport.id.label('diagnosis_id'),
        DiagnosisReport.severity,
        DiagnosisReport.created_at,
        Crop.crop_type.label('crop_name'),
        KnowledgeBase.name.label('kb_name'),
        DiagnosisReport.model_version.label('raw_label'),
        func.ST_Y(cast(loc_col, Geometry)).label('latitude'),
        func.ST_X(cast(loc_col, Geometry)).label('longitude')
    ).join(Crop, DiagnosisReport.crop_id == Crop.id)\
     .join(Farm, Crop.farm_id == Farm.id)\
     .outerjoin(KnowledgeBase, DiagnosisReport.disease_id == KnowledgeBase.id)\
     .filter(DiagnosisReport.status != DiagnosisStatus.REJECTED)\
     .filter(loc_col.isnot(None))

    if disease_name and disease_name.strip():
        query = query.filter(
            (KnowledgeBase.name.ilike(f"%{disease_name.strip()}%")) |
            (DiagnosisReport.model_version.ilike(f"%{disease_name.strip()}%"))
        )

    if radius_km is not None and lat is not None and lng is not None:
        try:
            valid_lat = float(lat)
            valid_lng = float(lng)
            if -90.0 <= valid_lat <= 90.0 and -180.0 <= valid_lng <= 180.0 and radius_km > 0:
                target_point = func.ST_SetSRID(func.ST_MakePoint(valid_lng, valid_lat), 4326)
                target_geog = cast(target_point, Geography)
                radius_meters = radius_km * 1000
                query = query.filter(func.ST_Distance(loc_col, target_geog) <= radius_meters)
        except Exception:
            pass  # Fall back to returning all hotspot reports safely

    results = query.all()
    
    locations = []
    high_sev_by_disease = defaultdict(list)
    
    for row in results:
        if row.latitude is not None and row.longitude is not None:
            dis_name = row.kb_name or row.raw_label or "Unknown Condition"
            sev_val = row.severity.value if hasattr(row.severity, 'value') else str(row.severity)
            locations.append(HotspotLocation(
                diagnosis_id=row.diagnosis_id,
                latitude=row.latitude,
                longitude=row.longitude,
                severity=sev_val,
                timestamp=row.created_at,
                disease_name=dis_name,
                crop_name=row.crop_name or "Crop"
            ))
            
            if sev_val in ["HIGH", "CRITICAL"]:
                high_sev_by_disease[dis_name].append((row.latitude, row.longitude))
                
    clusters_out = []
    kms_per_radian = 6371.0088
    eps = 15.0 / kms_per_radian
    
    for dis, coords in high_sev_by_disease.items():
        if len(coords) < 3:
            continue
            
        rad_coords = [(radians(lat), radians(lng)) for lat, lng in coords]
        X = np.array(rad_coords)
        dbscan = DBSCAN(eps=eps, min_samples=3, algorithm='ball_tree', metric='haversine')
        labels = dbscan.fit_predict(X)
        
        clusters_dict = defaultdict(list)
        for i, label in enumerate(labels):
            if label != -1:
                clusters_dict[label].append(coords[i])
                
        for label, pts in clusters_dict.items():
            avg_lat = sum(p[0] for p in pts) / len(pts)
            avg_lng = sum(p[1] for p in pts) / len(pts)
            
            clusters_out.append(OutbreakCluster(
                latitude=avg_lat,
                longitude=avg_lng,
                disease_name=dis,
                case_count=len(pts),
                radius_km=15.0
            ))
            
    return HotspotResponse(
        disease_name=disease_name or "All Outbreaks",
        hotspots=locations,
        clusters=clusters_out
    )
