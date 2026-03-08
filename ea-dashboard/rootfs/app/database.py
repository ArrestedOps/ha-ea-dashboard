"""
Database connection and initialization
"""
import aiosqlite
import os
from contextlib import asynccontextmanager
from pathlib import Path

DATABASE_PATH = os.getenv('DATABASE_PATH', '/data/dashboard.db')

async def init_db():
    """Initialize database with schema"""
    schema_path = Path(__file__).parent / 'schema.sql'
    
    async with aiosqlite.connect(DATABASE_PATH) as db:
        # Read and execute schema
        with open(schema_path, 'r') as f:
            schema_sql = f.read()
        
        await db.executescript(schema_sql)
        await db.commit()
        
        print(f"✓ Database initialized: {DATABASE_PATH}")

@asynccontextmanager
async def get_db():
    """Get database connection with context manager"""
    async with aiosqlite.connect(DATABASE_PATH) as db:
        # Enable Row factory for dict-like access
        db.row_factory = aiosqlite.Row
        
        # WAL mode for better concurrency
        await db.execute('PRAGMA journal_mode=WAL')
        
        try:
            yield db
        finally:
            await db.commit()

async def execute_query(query: str, params: tuple = ()):
    """Execute a query and return results"""
    async with get_db() as db:
        cursor = await db.execute(query, params)
        return await cursor.fetchall()

async def execute_update(query: str, params: tuple = ()):
    """Execute an update/insert query"""
    async with get_db() as db:
        cursor = await db.execute(query, params)
        await db.commit()
        return cursor.lastrowid
