"""Strict, identifier-free diagnostic ingestion. No request/access logging."""
import json
import os
import re
import sqlite3
import threading
from datetime import datetime, timedelta, timezone
from http.server import BaseHTTPRequestHandler, HTTPServer

DB = os.environ.get('DIAGNOSTICS_DB', '/var/lib/ads-recovery/diagnostics.sqlite3')
KINDS = {'scan', 'reloadSent', 'reloadCancelled', 'interfaceAppeared', 'outcomeUnknown'}
STATES = {'outside', 'unknown', 'loading', 'interfaceReady', 'unsafe'}
METHODS = {'none', 'manual', 'automatic'}

def validate(data):
    if not isinstance(data, dict) or set(data) != {'schema', 'appVersion', 'macOS', 'architecture', 'events'}:
        raise ValueError('schema')
    if type(data['schema']) is not int or data['schema'] != 1:
        raise ValueError('version')
    for key in ('appVersion', 'macOS'):
        if not isinstance(data[key], str) or not re.fullmatch(r'[0-9]{1,3}\.[0-9]{1,3}(\.[0-9]{1,3})?', data[key]):
            raise ValueError('version')
    if data['architecture'] not in ('arm64', 'x86_64'):
        raise ValueError('architecture')
    if not isinstance(data['events'], list) or not 1 <= len(data['events']) <= 50:
        raise ValueError('batch')
    for event in data['events']:
        if not isinstance(event, dict) or set(event) != {'kind', 'state', 'method', 'milliseconds'}:
            raise ValueError('event')
        if not isinstance(event['kind'], str) or event['kind'] not in KINDS:
            raise ValueError('kind')
        if not isinstance(event['state'], str) or event['state'] not in STATES:
            raise ValueError('state')
        if not isinstance(event['method'], str) or event['method'] not in METHODS:
            raise ValueError('method')
        if type(event['milliseconds']) is not int or not 0 <= event['milliseconds'] <= 120000:
            raise ValueError('duration')
    return data

def connect():
    connection = sqlite3.connect(DB, timeout=5)
    connection.execute('''CREATE TABLE IF NOT EXISTS totals (
        day TEXT, app TEXT, os TEXT, arch TEXT, kind TEXT, state TEXT, method TEXT,
        count INTEGER, milliseconds INTEGER,
        PRIMARY KEY(day, app, os, arch, kind, state, method))''')
    return connection

def prune(connection):
    cutoff = (datetime.now(timezone.utc) - timedelta(days=29)).date().isoformat()
    connection.execute('DELETE FROM totals WHERE day < ?', (cutoff,))

def store(data):
    with connect() as db:
        prune(db)
        # Bound storage even when an unauthenticated sender fabricates versions.
        if db.execute('SELECT count(*) FROM totals').fetchone()[0] >= 50000:
            return False
        day = datetime.now(timezone.utc).date().isoformat()
        for event in data['events']:
            db.execute('''INSERT INTO totals VALUES (?,?,?,?,?,?,?,1,?)
                ON CONFLICT(day,app,os,arch,kind,state,method) DO UPDATE SET
                count=count+1, milliseconds=milliseconds+excluded.milliseconds''',
                (day, data['appVersion'], data['macOS'], data['architecture'], event['kind'],
                 event['state'], event['method'], event['milliseconds']))
    return True

class Handler(BaseHTTPRequestHandler):
    server_version = 'Diagnostics'
    sys_version = ''
    def setup(self):
        super().setup()
        self.connection.settimeout(10)
    def log_message(self, *args):
        pass
    def reply(self, code):
        self.send_response(code)
        self.send_header('Content-Length', '0')
        self.send_header('Cache-Control', 'no-store')
        self.end_headers()
    def do_GET(self):
        self.reply(204 if self.path == '/health' else 404)
    def do_POST(self):
        if self.path != '/ads-recovery/v1/events':
            return self.reply(404)
        if self.headers.get('Content-Type') != 'application/json' or self.headers.get('Transfer-Encoding'):
            return self.reply(415)
        try:
            size = int(self.headers.get('Content-Length', '0'))
            if not 0 < size <= 8192:
                return self.reply(413)
            data = validate(json.loads(self.rfile.read(size)))
        except (ValueError, TypeError, UnicodeError, TimeoutError):
            return self.reply(400)
        try:
            self.reply(204 if store(data) else 503)
        except sqlite3.Error:
            self.reply(503)

class Server(HTTPServer):
    def handle_error(self, request, client_address):
        pass  # Never write client addresses or request details to stderr.

def cleanup_forever():
    while True:
        with connect() as db:
            prune(db)
        threading.Event().wait(3600)

if __name__ == '__main__':
    threading.Thread(target=cleanup_forever, daemon=True).start()
    Server(('127.0.0.1', int(os.environ.get('PORT', '5187'))), Handler).serve_forever()
