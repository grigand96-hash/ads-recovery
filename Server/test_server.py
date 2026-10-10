import copy
import json
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch
import server

class DiagnosticsTests(unittest.TestCase):
    def setUp(self):
        self.payload = dict(schema=1, appVersion='0.1.0', macOS='27.0', architecture='arm64', events=[dict(kind='scan', state='loading', method='none', milliseconds=42)])
    def test_rejects_private_or_unstructured_fields(self):
        for key in ['url', 'accountID', 'cookie', 'userID', 'message']:
            payload = copy.deepcopy(self.payload); payload[key] = 'private'
            with self.assertRaises(ValueError): server.validate(payload)
            payload = copy.deepcopy(self.payload); payload['events'][0][key] = 'private'
            with self.assertRaises(ValueError): server.validate(payload)
        for field in ['kind', 'state', 'method']:
            payload = copy.deepcopy(self.payload); payload['events'][0][field] = 'arbitrary page text'
            with self.assertRaises(ValueError): server.validate(payload)
    def test_bounds(self):
        for events in [[], self.payload['events'] * 51]:
            payload = dict(self.payload, events=events)
            with self.assertRaises(ValueError): server.validate(payload)
        self.payload['events'][0]['milliseconds'] = True
        with self.assertRaises(ValueError): server.validate(self.payload)
    def test_aggregates_and_prunes(self):
        with tempfile.TemporaryDirectory() as tmp, patch.object(server, 'DB', str(Path(tmp)/'test.sqlite3')):
            server.store(server.validate(self.payload)); server.store(self.payload)
            with server.connect() as db:
                row = db.execute('SELECT count, milliseconds FROM totals').fetchone()
                self.assertEqual(row, (2,84))
                db.execute("UPDATE totals SET day='2000-01-01'")
                server.prune(db)
                self.assertEqual(db.execute('SELECT count(*) FROM totals').fetchone()[0],0)

if __name__ == '__main__': unittest.main()
