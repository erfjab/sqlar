from sqlalchemy.ext.asyncio import create_async_engine
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import sessionmaker
from sqlalchemy import text
from .config import DB_ADDRESS

class SimpleDatabase:
    def __init__(self, database_url):
        self.database_url = database_url
        self.engine = None
        self.session = None

    async def connect(self):
        self.engine = create_async_engine(self.database_url, echo=True)
        self.session = sessionmaker(
            bind=self.engine, class_=AsyncSession, expire_on_commit=False
        )()

    async def execute_query(self, query):
        async with self.session.begin():
            result = await self.session.execute(text(query))
            return result.fetchall()

    async def disconnect(self):
        await self.session.close()
        await self.engine.dispose()

db = SimpleDatabase(DB_ADDRESS)