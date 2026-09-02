#!/usr/bin/env python3
"""
MediTrack - Bangladesh Medicine Reference Database Builder
Converts raw CSV files from medicine_dataset/ into an optimized, indexed SQLite database.
Output: assets/data/medicine_catalog.db
"""

import os
import sys
import csv
import re
import html
import sqlite3

def clean_text(raw):
    if not raw:
        return ''
    # Replace line break HTML tags with newlines
    text = re.sub(r'<(?:br|p|/p|li)\s*/?>', '\n', raw, flags=re.IGNORECASE)
    # Strip remaining HTML tags
    text = re.sub(r'<[^>]+>', '', text)
    # Decode HTML entities like &amp;, &nbsp;, etc.
    text = html.unescape(text)
    # Normalize multiple whitespaces and empty lines
    lines = [line.strip() for line in text.splitlines()]
    text = '\n'.join([l for l in lines if l])
    return text.strip()

def extract_prices(container, package_size):
    unit_price = None
    pack_price = None
    
    combined = f"{container} {package_size}"

    # 1. Look for explicit "Unit Price: ৳ 5.98"
    m_unit = re.search(r'unit\s*price\s*[:\s]*[৳Tk\.\s]*([\d\.]+)', combined, re.IGNORECASE)
    if m_unit:
        try:
            unit_price = float(m_unit.group(1))
        except ValueError:
            pass

    # 2. Look for "(100's pack: ৳ 598.00)" or similar pack price
    m_pack = re.search(r"\(\s*[\d\w\s'\.]*pack\s*[:\s]*[৳Tk\.\s]*([\d\.]+)\s*\)", combined, re.IGNORECASE)
    if m_pack:
        try:
            pack_price = float(m_pack.group(1))
        except ValueError:
            pass

    # 3. If unit_price not found, look for single item format: "100 ml bottle: ৳ 40.12" or "250 mg vial: ৳ 20.00"
    if unit_price is None:
        m_single = re.search(r'(?:bottle|vial|tube|ampoule|sachet|drop|spray|cream|ointment|gel|syrup|suspension|inhaler|canister|pack|piece|strip|box|tablet|capsule|piece|suppository)?\s*[:\s]*[৳Tk\.\s]*([\d\.]+)', container, re.IGNORECASE)
        if m_single:
            try:
                unit_price = float(m_single.group(1))
            except ValueError:
                pass

    # 4. Fallback: Any taka symbol followed by numbers if still nothing
    if unit_price is None and pack_price is None:
        m_any = re.search(r'[৳Tk\.]+\s*([\d\.]+)', container)
        if m_any:
            try:
                unit_price = float(m_any.group(1))
            except ValueError:
                pass

    return unit_price, pack_price

def build_database(dataset_dir="medicine_dataset", output_db="assets/data/medicine_catalog.db"):
    os.makedirs(os.path.dirname(output_db), exist_ok=True)
    
    if os.path.exists(output_db):
        os.remove(output_db)

    print(f"Creating database at: {output_db}")
    conn = sqlite3.connect(output_db)
    cursor = conn.cursor()

    # Enable WAL mode and synchronous normal for high performance
    cursor.execute("PRAGMA journal_mode = OFF;")
    cursor.execute("PRAGMA synchronous = OFF;")
    cursor.execute("PRAGMA page_size = 4096;")

    # 1. Create tables
    cursor.execute("""
    CREATE TABLE IF NOT EXISTS medicines (
        id INTEGER PRIMARY KEY,
        brand_name TEXT NOT NULL,
        generic_name TEXT NOT NULL,
        dosage_form TEXT,
        strength TEXT,
        manufacturer TEXT,
        type TEXT,
        package_container TEXT,
        package_size TEXT,
        unit_price REAL,
        pack_price REAL,
        search_name TEXT NOT NULL
    );
    """)

    cursor.execute("""
    CREATE TABLE IF NOT EXISTS generics (
        id INTEGER PRIMARY KEY,
        generic_name TEXT NOT NULL,
        slug TEXT,
        drug_class TEXT,
        indication TEXT,
        monograph_link TEXT,
        indication_desc TEXT,
        therapeutic_class_desc TEXT,
        pharmacology_desc TEXT,
        dosage_desc TEXT,
        administration_desc TEXT,
        interaction_desc TEXT,
        contraindications_desc TEXT,
        side_effects_desc TEXT,
        pregnancy_desc TEXT,
        precautions_desc TEXT,
        pediatric_desc TEXT,
        overdose_desc TEXT,
        duration_desc TEXT,
        reconstitution_desc TEXT,
        storage_desc TEXT
    );
    """)

    cursor.execute("""
    CREATE TABLE IF NOT EXISTS manufacturers (
        id INTEGER PRIMARY KEY,
        name TEXT NOT NULL,
        slug TEXT,
        generics_count INTEGER,
        brands_count INTEGER
    );
    """)

    cursor.execute("""
    CREATE TABLE IF NOT EXISTS indications (
        id INTEGER PRIMARY KEY,
        name TEXT NOT NULL,
        slug TEXT,
        generics_count INTEGER
    );
    """)

    cursor.execute("""
    CREATE TABLE IF NOT EXISTS drug_classes (
        id INTEGER PRIMARY KEY,
        name TEXT NOT NULL,
        slug TEXT,
        generics_count INTEGER
    );
    """)

    cursor.execute("""
    CREATE TABLE IF NOT EXISTS dosage_forms (
        id INTEGER PRIMARY KEY,
        name TEXT NOT NULL,
        slug TEXT,
        brands_count INTEGER
    );
    """)

    # 2. Insert Dosage Forms
    dosage_form_file = os.path.join(dataset_dir, "dosage form.csv")
    if os.path.exists(dosage_form_file):
        with open(dosage_form_file, "r", encoding="utf-8", errors="ignore") as f:
            reader = csv.reader(f)
            next(reader, None) # skip header
            rows = []
            for r in reader:
                if len(r) >= 4:
                    try:
                        rows.append((int(r[0]), r[1].strip(), r[2].strip(), int(r[3]) if r[3].isdigit() else 0))
                    except ValueError:
                        continue
            cursor.executemany("INSERT INTO dosage_forms (id, name, slug, brands_count) VALUES (?, ?, ?, ?)", rows)
        print(f"  Inserted {len(rows)} dosage forms")

    # 3. Insert Drug Classes
    drug_class_file = os.path.join(dataset_dir, "drug class.csv")
    if os.path.exists(drug_class_file):
        with open(drug_class_file, "r", encoding="utf-8", errors="ignore") as f:
            reader = csv.reader(f)
            next(reader, None)
            rows = []
            for r in reader:
                if len(r) >= 4:
                    try:
                        rows.append((int(r[0]), r[1].strip(), r[2].strip(), int(r[3]) if r[3].isdigit() else 0))
                    except ValueError:
                        continue
            cursor.executemany("INSERT INTO drug_classes (id, name, slug, generics_count) VALUES (?, ?, ?, ?)", rows)
        print(f"  Inserted {len(rows)} drug classes")

    # 4. Insert Indications
    indication_file = os.path.join(dataset_dir, "indication.csv")
    if os.path.exists(indication_file):
        with open(indication_file, "r", encoding="utf-8", errors="ignore") as f:
            reader = csv.reader(f)
            next(reader, None)
            rows = []
            for r in reader:
                if len(r) >= 4:
                    try:
                        rows.append((int(r[0]), r[1].strip(), r[2].strip(), int(r[3]) if r[3].isdigit() else 0))
                    except ValueError:
                        continue
            cursor.executemany("INSERT INTO indications (id, name, slug, generics_count) VALUES (?, ?, ?, ?)", rows)
        print(f"  Inserted {len(rows)} indications")

    # 5. Insert Manufacturers
    mfg_file = os.path.join(dataset_dir, "manufacturer.csv")
    if os.path.exists(mfg_file):
        with open(mfg_file, "r", encoding="utf-8", errors="ignore") as f:
            reader = csv.reader(f)
            next(reader, None)
            rows = []
            for r in reader:
                if len(r) >= 5:
                    try:
                        rows.append((
                            int(r[0]),
                            r[1].strip(),
                            r[2].strip(),
                            int(r[3]) if r[3].isdigit() else 0,
                            int(r[4]) if r[4].isdigit() else 0
                        ))
                    except ValueError:
                        continue
            cursor.executemany("INSERT INTO manufacturers (id, name, slug, generics_count, brands_count) VALUES (?, ?, ?, ?, ?)", rows)
        print(f"  Inserted {len(rows)} manufacturers")

    # 6. Insert Generics
    generic_file = os.path.join(dataset_dir, "generic.csv")
    if os.path.exists(generic_file):
        with open(generic_file, "r", encoding="utf-8", errors="ignore") as f:
            reader = csv.reader(f)
            next(reader, None)
            rows = []
            for r in reader:
                if len(r) >= 6:
                    try:
                        gid = int(r[0])
                        gname = r[1].strip()
                        slug = r[2].strip()
                        monograph = r[3].strip()
                        drug_class = r[4].strip()
                        indication = r[5].strip()
                        
                        # Clean HTML text for all descriptions
                        indication_desc = clean_text(r[6]) if len(r) > 6 else ""
                        therapeutic_class_desc = clean_text(r[7]) if len(r) > 7 else ""
                        pharmacology_desc = clean_text(r[8]) if len(r) > 8 else ""
                        dosage_desc = clean_text(r[9]) if len(r) > 9 else ""
                        administration_desc = clean_text(r[10]) if len(r) > 10 else ""
                        interaction_desc = clean_text(r[11]) if len(r) > 11 else ""
                        contraindications_desc = clean_text(r[12]) if len(r) > 12 else ""
                        side_effects_desc = clean_text(r[13]) if len(r) > 13 else ""
                        pregnancy_desc = clean_text(r[14]) if len(r) > 14 else ""
                        precautions_desc = clean_text(r[15]) if len(r) > 15 else ""
                        pediatric_desc = clean_text(r[16]) if len(r) > 16 else ""
                        overdose_desc = clean_text(r[17]) if len(r) > 17 else ""
                        duration_desc = clean_text(r[18]) if len(r) > 18 else ""
                        reconstitution_desc = clean_text(r[19]) if len(r) > 19 else ""
                        storage_desc = clean_text(r[20]) if len(r) > 20 else ""

                        rows.append((
                            gid, gname, slug, drug_class, indication, monograph,
                            indication_desc, therapeutic_class_desc, pharmacology_desc,
                            dosage_desc, administration_desc, interaction_desc,
                            contraindications_desc, side_effects_desc, pregnancy_desc,
                            precautions_desc, pediatric_desc, overdose_desc,
                            duration_desc, reconstitution_desc, storage_desc
                        ))
                    except ValueError:
                        continue
            cursor.executemany("""
            INSERT INTO generics (
                id, generic_name, slug, drug_class, indication, monograph_link,
                indication_desc, therapeutic_class_desc, pharmacology_desc,
                dosage_desc, administration_desc, interaction_desc,
                contraindications_desc, side_effects_desc, pregnancy_desc,
                precautions_desc, pediatric_desc, overdose_desc,
                duration_desc, reconstitution_desc, storage_desc
            ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
            """, rows)
        print(f"  Inserted {len(rows)} generics")

    # 7. Insert Medicines
    med_file = os.path.join(dataset_dir, "medicine.csv")
    if os.path.exists(med_file):
        with open(med_file, "r", encoding="utf-8", errors="ignore") as f:
            reader = csv.reader(f)
            next(reader, None)
            rows = []
            seen_ids = set()
            for r in reader:
                if len(r) >= 8:
                    try:
                        raw_id = r[0].strip()
                        if not raw_id.isdigit():
                            continue
                        mid = int(raw_id)
                        if mid in seen_ids:
                            continue
                        seen_ids.add(mid)

                        brand_name = r[1].strip()
                        mtype = r[2].strip()
                        slug = r[3].strip()
                        dosage_form = r[4].strip()
                        generic_name = r[5].strip()
                        strength = r[6].strip()
                        manufacturer = r[7].strip()
                        package_container = r[8].strip() if len(r) > 8 else ""
                        package_size = r[9].strip() if len(r) > 9 else ""

                        if not brand_name or not generic_name:
                            continue

                        unit_price, pack_price = extract_prices(package_container, package_size)
                        search_name = f"{brand_name} {generic_name}".lower().strip()

                        rows.append((
                            mid, brand_name, generic_name, dosage_form, strength,
                            manufacturer, mtype, package_container, package_size,
                            unit_price, pack_price, search_name
                        ))
                    except ValueError:
                        continue

            cursor.executemany("""
            INSERT INTO medicines (
                id, brand_name, generic_name, dosage_form, strength,
                manufacturer, type, package_container, package_size,
                unit_price, pack_price, search_name
            ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
            """, rows)
        print(f"  Inserted {len(rows)} medicines")

    # 8. Create Indexes for High-Performance Queries
    print("Creating database indexes...")
    cursor.execute("CREATE INDEX idx_medicines_brand ON medicines(brand_name COLLATE NOCASE);")
    cursor.execute("CREATE INDEX idx_medicines_generic ON medicines(generic_name COLLATE NOCASE);")
    cursor.execute("CREATE INDEX idx_medicines_search ON medicines(search_name);")
    cursor.execute("CREATE INDEX idx_medicines_mfg ON medicines(manufacturer COLLATE NOCASE);")
    cursor.execute("CREATE INDEX idx_medicines_price ON medicines(unit_price);")
    cursor.execute("CREATE INDEX idx_generics_name ON generics(generic_name COLLATE NOCASE);")
    cursor.execute("CREATE INDEX idx_generics_drug_class ON generics(drug_class COLLATE NOCASE);")
    cursor.execute("CREATE INDEX idx_generics_indication ON generics(indication COLLATE NOCASE);")

    # 9. Create Full-Text Search (FTS5) Virtual Table for fast, typo-tolerant/substring searches
    print("Creating FTS5 Full-Text Search Virtual Table...")
    cursor.execute("""
    CREATE VIRTUAL TABLE medicines_fts USING fts5(
        brand_name,
        generic_name,
        manufacturer,
        dosage_form,
        strength,
        content='medicines',
        content_rowid='id'
    );
    """)

    cursor.execute("""
    INSERT INTO medicines_fts(rowid, brand_name, generic_name, manufacturer, dosage_form, strength)
    SELECT id, brand_name, generic_name, manufacturer, dosage_form, strength FROM medicines;
    """)

    # Optimize and compact
    print("Optimizing and vacuuming SQLite database...")
    cursor.execute("INSERT INTO medicines_fts(medicines_fts) VALUES('optimize');")
    conn.commit()
    cursor.execute("VACUUM;")
    conn.close()

    db_size_mb = os.path.getsize(output_db) / (1024 * 1024)
    print(f"\nSUCCESS! Database built at '{output_db}' (Size: {db_size_mb:.2f} MB)")

if __name__ == "__main__":
    build_database()
