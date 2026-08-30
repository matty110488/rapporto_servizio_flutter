import assert from 'node:assert/strict';
import test from 'node:test';

import {
  allowedRaceDatabaseIds,
  DEFAULT_RACE_DATABASE_IDS,
  NOTION_RACE_PROPERTIES,
} from '../api/notion-config.js';

test('backend annual database allowlist contains the configured defaults', () => {
  assert.deepEqual(DEFAULT_RACE_DATABASE_IDS, [
    '2afde089ef9580e2b0e7d19d44f3a3f6',
    '2b1de089ef9580729622ff9543046cbc',
    '39bde089ef958021a47cd012c593d249',
  ]);
});

test('backend accepts extra annual databases from Vercel configuration', () => {
  const extra = 'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
  assert.deepEqual(allowedRaceDatabaseIds(` ${extra} `), [
    ...DEFAULT_RACE_DATABASE_IDS,
    extra,
  ]);
  assert.equal(NOTION_RACE_PROPERTIES.files, 'Files & media');
});
