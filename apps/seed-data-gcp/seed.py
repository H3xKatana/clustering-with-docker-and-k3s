#!/usr/bin/env python3
"""Seed the votes database with sample data. Run as a Cloud Run Job."""
import os
import psycopg2

conn = psycopg2.connect(
    user=os.environ['DB_USER'],
    password=os.environ['DB_PASSWORD'],
    dbname=os.environ['DB_NAME'],
    host=os.environ['DB_HOST'],
)

cur = conn.cursor()
cur.execute("""
    CREATE TABLE IF NOT EXISTS votes (
        id VARCHAR(255) NOT NULL UNIQUE,
        vote VARCHAR(255) NOT NULL
    )
""")

sample = [
    ("seed-a1", "a"), ("seed-a2", "a"), ("seed-a3", "a"),
    ("seed-a4", "a"), ("seed-a5", "a"),
    ("seed-b1", "b"), ("seed-b2", "b"), ("seed-b3", "b"),
    ("seed-b4", "b"), ("seed-b5", "b"),
]
for vid, v in sample:
    try:
        cur.execute("INSERT INTO votes (id, vote) VALUES (%s, %s)", (vid, v))
    except psycopg2.errors.UniqueViolation:
        conn.rollback()
        cur.execute("UPDATE votes SET vote = %s WHERE id = %s", (v, vid))
    else:
        conn.commit()

cur.close()
conn.close()
print("Seeded 10 votes (5 cats, 5 dogs)")
