#! /usr/bin/env python
import argparse

import pandas as pd
import psycopg
import pymssql


def test_database(server_name, hostname, port, db_type, db_name, username, password):
    print(f"Attempting to connect to '{db_name}' on '{server_name}' via port {port}")
    username_full = f"{username}@{hostname}"
    cnxn = None
    if db_type == "mssql":
        cnxn = pymssql.connect(
            server=server_name, user=username_full, password=password, database=db_name
        )
    elif db_type == "postgresql":
        connection_string = f"host={server_name} port={port} dbname={db_name} user={username_full} password={password}"
        cnxn = psycopg.connect(connection_string)
    else:
        raise ValueError(f"Database type '{db_type}' was not recognised")
    df = pd.read_sql("SELECT * FROM information_schema.tables;", cnxn)
    if df.size:
        print(df.head(5))
        print("All database tests passed")
    else:
        raise ValueError(f"Reading from database '{db_name}' failed.")


# Parse command line arguments
parser = argparse.ArgumentParser()
parser.add_argument(
    "--db-type",
    type=str,
    choices=["mssql", "postgresql"],
    help="Which database type to use",
)
parser.add_argument("--db-name", type=str, help="Which database to connect to")
parser.add_argument("--port", type=str, help="Which port to connect to")
parser.add_argument("--server-name", type=str, help="Which server to connect to")
parser.add_argument("--username", type=str, help="Database username")
parser.add_argument("--hostname", type=str, help="Azure hostname of the server")
parser.add_argument("--password", type=str, help="Database user password")
args = parser.parse_args()

# Run database test
test_database(
    args.server_name,
    args.hostname,
    args.port,
    args.db_type,
    args.db_name,
    args.username,
    args.password,
)
