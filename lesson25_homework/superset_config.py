import os

   SQLALCHEMY_DATABASE_URI = f"postgresql+psycopg2://superset:superset@superset_db:5432/superset"
   SECRET_KEY = "your_secret_key_here"

   FEATURE_FLAGS = {
       "VERSIONED_EXPORT": True,
   }

   ROW_LIMIT = 5000