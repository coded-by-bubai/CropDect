import psycopg

conn_info = "dbname=cropdect_db user=postgres password=postgres host=localhost port=5432"

try:
    with psycopg.connect(conn_info) as conn:
        with conn.cursor() as cur:
            try:
                cur.execute("ALTER TABLE diagnosis_reports ADD COLUMN infection_temp_c FLOAT;")
                print("Added infection_temp_c successfully.")
            except Exception as e:
                print("infection_temp_c error or already exists:", e)
                conn.rollback()
                
            try:
                cur.execute("ALTER TABLE diagnosis_reports ADD COLUMN infection_humidity_percent FLOAT;")
                print("Added infection_humidity_percent successfully.")
            except Exception as e:
                print("infection_humidity_percent error or already exists:", e)
                conn.rollback()
                
        conn.commit()
except Exception as e:
    print("Connection failed:", e)
